

#' Post-process the netCDF files for easy use by models and to generate derived variables
#' 
#' For now, I've only built this for Top Predator Watch based on CMEMS products. But ideally this will be expanded to include other tools and these can be specified using the `tool` argument
#'
#' @param infile The full file path for the netCDF file to be imported to R as a SpatRaster.
#' @param indir Directory to which the netCDF files are imported.
#' @param variable The name for the variable of interest.
#' @param outdir Directory to which processed netCDF files are saved.
#' @param savename The file name to save the processed raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param tool NOT CURRENTLY USED; this could specify which variables should be calculated and how depending on the tool selected.
#' @param template A SpatRaster layer of the spatial extent, resolution, and projection of interest for the particular tool.
#'
#' @return A geoTIFF file is exported locally to the `outdir` path that was specified.
#' 
#' @export
process_vars = function(infile, indir, variable, outdir, savename, get_date, tool = NULL, template) {
  
  # Only attempt to process if file exists
  if (file.exists(glue("{indir}/{infile}"))) {
    
    r <- rast(glue("{indir}/{infile}"))  # read in raster layer
    
    
    # Adjust SST units
    if (variable == 'analysed_sst') {
      r <- r - 273.15  # convert to celsius
      units(r) <- "celsius"
    }
    
    # Process raster by shifting extent and resampling to template
    if(ext(r)[1] < (-100)){
      r <- rotate(r, left = FALSE)  # convert lon extent from (-180,180) to (0,360)
    }
    
    # Resample raster by template
    r2 <- resample(r, template)  
    time(r2) <- NULL  #prevent creation of aux.json files (associated w/ times or units)
    
    # Smooth over over 5x5 window (1.25 deg) (but not for geostrophic currents)
    if (!variable %in% c('ugosa','vgosa')) {
      
      r2_mean <- focal(r2, w = matrix(1, nrow = 5, ncol = 5), fun = mean, na.rm = TRUE)
      writeRaster(r2_mean, glue("{outdir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
      
    } else {
      
      writeRaster(r2, glue("{outdir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
      
    }
    
  } else {
    message(glue("{infile} doesn't exist"))
  }
  
  
  
  
}




#' Calculated derived variables from downloaded products
#' 
#' For now, I've only built this for Top Predator Watch based on CMEMS products. But ideally this will be expanded to include other tools and these can be specified using the `tool` argument.
#'
#' @param dir The directory from which to read and write derived variables.
#' @param variable Name of derived variable of interest.
#' @param savename The file name to save the derived raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param tool NOT CURRENTLY USED; this could specify which variables should be calculated and how depending on the tool selected.
#'
#' @return A geoTIFF file is exported locally to the directories specified in the function.
#' 
#' @export
calc_derived_vars = function(dir, variable, savename, get_date, tool = NULL) {
  
  
  if (variable == 'sst_sd') {  # Calculate SST_sd
    
    sst_sd <- rast(glue("{dir}/sst_{get_date}.tiff")) |> 
      focal(w = matrix(1, nrow = 5, ncol = 5), fun = sd, na.rm = TRUE)
    writeRaster(sst_sd, glue("{dir}/sst_sd.tiff"), overwrite = TRUE)
    
  } else if (variable == 'eke') {  # Calculate EKE
    
    u <- rast(glue("{dir}/ugosa_{get_date}.tiff"))
    v <- rast(glue("{dir}/ugosa_{get_date}.tiff"))
    
    eke <- 0.5 * (u^2 + v^2)
    l.eke <- log10(eke + 0.001)
    eke_mean <- focal(l.eke, w = matrix(1, nrow = 5, ncol = 5), fun = mean, na.rm = TRUE)
    writeRaster(eke_mean, glue("{dir}/eke_{get_date}.tiff"), overwrite = TRUE)
    
  }
  
}
