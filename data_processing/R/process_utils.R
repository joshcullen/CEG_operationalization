

#' Post-process the netCDF files for easy use by models and to generate derived variables
#' 
#' This function can currently be used for Top Predator Watch (based on CMEMS products) or the ROMS tool (based on ROMS products). But ideally this will be expanded to include other tools and these can be specified using the `tool` argument.
#'
#' @param infile The full file path for the netCDF file to be imported to R as a SpatRaster.
#' @param indir Directory to which the netCDF files are imported.
#' @param variable The name for the variable of interest.
#' @param outdir Directory to which processed netCDF files are saved.
#' @param savename The file name to save the processed raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param tool Name of the tool to for data processing; 'TopPredatorWatch' or 'ROMS'.
#' @param template A SpatRaster layer of the spatial extent, resolution, and projection of interest for the particular tool.
#'
#' @return A geoTIFF file is exported locally to the `outdir` path that was specified.
#' 
#' @export
process_vars = function(infile, indir, variable, outdir, savename, get_date, tool, template) {
  
  switch(tool,
         "TopPredatorWatch" = process_vars_TopPred(infile = infile,
                                                   indir = indir,
                                                   variable = variable,
                                                   outdir = outdir,
                                                   savename = savename,
                                                   get_date = get_date,
                                                   template = template),
         
         "ROMS" = process_vars_ROMS(infile = infile,
                                    indir = indir,
                                    variable = variable,
                                    outdir = outdir,
                                    savename = savename,
                                    get_date = get_date,
                                    template = template),
         
         stop("Tool must be one of either 'TopPredatorWatch' or 'ROMS'.")
  )
  
}




#' Post-process the netCDF files for easy use by Top Predator Watch tool
#' 
#' This function is specifically built for Top Predator Watch based on CMEMS products. Other functions are available for processing covariates for other tools.
#'
#' @param infile The full file path for the netCDF file to be imported to R as a SpatRaster.
#' @param indir Directory to which the netCDF files are imported.
#' @param variable The name for the variable of interest.
#' @param outdir Directory to which processed netCDF files are saved.
#' @param savename The file name to save the processed raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param template A SpatRaster layer of the spatial extent, resolution, and projection of interest for the particular tool.
#'
#' @return A geoTIFF file is exported locally to the `outdir` path that was specified.
#' 
process_vars_TopPred = function(infile, indir, variable, outdir, savename, get_date, template) {
  
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
    
    # Average NPP over Z-dimension
    if (variable == 'nppv') {
      r <- mean(r, na.rm = TRUE)
    }
    
    # Resample raster by template
    r2 <- resample(r, template)  
    time(r2) <- NULL  #prevent creation of aux.json files (associated w/ times or units)
    
    
    # Remove "no data" values added for sla, ugosa, and vgosa
    if (variable %in% c('sla','ugosa','vgosa')) {
      r2[r2 < -1000] <- NA
    }
    
    # Smooth over over 5x5 window (1.25 deg) (but not for geostrophic currents)
    if (!variable %in% c('ugosa','vgosa')) {
      
      units(r2) <- NULL  #need to remove to prevent creation of .aux.json files
      
      r2_mean <- focal(r2, w = matrix(1, nrow = 5, ncol = 5), fun = mean, na.rm = TRUE)
      writeRaster(r2_mean, glue("{outdir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
      
    } else {
      
      writeRaster(r2, glue("{outdir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
      
    }
    
  } else {
    message(glue("{infile} doesn't exist"))
  }
  
  
  # Create raster for day-of-year
  doy <- template
  doy[] <- yday(get_date)
  writeRaster(doy, glue("{outdir}/day_{get_date}.tiff"), overwrite = TRUE)
  
}




#' Post-process the netCDF files for easy use by the ROMS tool
#' 
#' This function is specifically built for the ROMS tool based on ROMS products. Other functions are available for processing covariates for other tools.
#'
#' @param infile The full file path for the netCDF file to be imported to R as a SpatRaster.
#' @param indir Directory to which the netCDF files are imported.
#' @param variable The name for the variable of interest.
#' @param outdir Directory to which processed netCDF files are saved.
#' @param savename The file name to save the processed raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param template A SpatRaster layer of the spatial extent, resolution, and projection of interest for the particular tool.
#'
#' @return A geoTIFF file is exported locally to the `outdir` path that was specified.
#' 
process_vars_ROMS = function(infile, indir, variable, outdir, savename, get_date, template) {
  
  # Only attempt to process if file exists
  if (file.exists(glue("{indir}/{infile}"))) {
    
    r <- rast(glue("{indir}/{infile}"))  # read in raster layer
    
    
    # Resample raster by template
    r2 <- resample(r, template, method = "bilinear")  
    writeRaster(r2, glue("{outdir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
    
  } else {
    message(glue("{infile} doesn't exist"))
  }
  
  
  # Create raster for lunar illumination (amount of moonlight hitting ocean surface; from the lunar package)
  lunar_value <- lunar.illumination(as_date(get_date))
  lunar_rast <- template
  values(lunar_rast) <- lunar_value
  writeRaster(lunar_rast, glue("{outdir}/lunar_{get_date}.tiff"), overwrite = TRUE)
  
  
  # Rename z and zsd (bathy and bathy standard deviation)
  if(!file.exists("data_processing/ROMS/static/z.tiff") |
     !file.exists("data_processing/ROMS/static/z_sd.tiff")) {
    
    z_rast <- rast("data_processing/ROMS/static/z_.1.grd")
    zsd_rast <- rast("data_processing/ROMS/static/zsd_.3.grd")
    
    writeRaster(z_rast, "data_processing/ROMS/static/z.tiff", overwrite = TRUE)
    writeRaster(zsd_rast, "data_processing/ROMS/static/z_sd.tiff", overwrite = TRUE)
    
  }
  
}




#' Calculated derived variables from downloaded products
#' 
#' This function can currently be used for Top Predator Watch (based on CMEMS products) or the ROMS tool (based on ROMS products). But ideally this will be expanded to include other tools and these can be specified using the `tool` argument.
#'
#' @param dir The directory from which to read and write derived variables.
#' @param variable Name of derived variable of interest.
#' @param savename The file name to save the derived raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param tool Name of the tool to for data processing; 'TopPredatorWatch' or 'ROMS'.
#'
#' @return A geoTIFF file is exported locally to the directories specified in the function.
#' 
#' @export
calc_derived_vars = function(dir, variable, savename, get_date, tool) {
  
  switch(tool,
         "TopPredatorWatch" = calc_derived_vars_TopPred(dir = dir,
                                                        variable = variable,
                                                        savename = savename,
                                                        get_date = get_date),
         
         "ROMS" = calc_derived_vars_ROMS(dir = dir,
                                         variable = variable,
                                         savename = savename,
                                         get_date = get_date),
         
         stop("Tool must be one of either 'TopPredatorWatch' or 'ROMS'.")
  )
  
}




#' Calculated derived variables from downloaded products for Top Predator Watch
#' 
#' This function is specifically built for Top Predator Watch based on CMEMS products. Other functions are available for processing covariates for other tools.
#'
#' @param dir The directory from which to read and write derived variables.
#' @param variable Name of derived variable of interest.
#' @param savename The file name to save the derived raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#'
#' @return A geoTIFF file is exported locally to the directories specified in the function.
#' 
calc_derived_vars_TopPred = function(dir, variable, savename, get_date) {
  
  
  if (variable == 'sst_sd') {  # Calculate SST_sd
    
    sst_sd <- rast(glue("{dir}/sst_{get_date}.tiff")) |> 
      focal(w = matrix(1, nrow = 5, ncol = 5), fun = sd, na.rm = TRUE)
    writeRaster(sst_sd, glue("{dir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
    
  } else if (variable == 'eke') {  # Calculate EKE
    
    u <- rast(glue("{dir}/ugosa_{get_date}.tiff"))
    v <- rast(glue("{dir}/vgosa_{get_date}.tiff"))
    
    eke <- 0.5 * (u^2 + v^2)
    l.eke <- log10(eke + 0.001)
    eke_mean <- focal(l.eke, w = matrix(1, nrow = 5, ncol = 5), fun = mean, na.rm = TRUE)
    writeRaster(eke_mean, glue("{dir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
    
  } else {
    stop("`variable` must be one of either 'sst_sd' or 'eke' when `tool = 'TopPredatorWatch'`.")
  }
  
}




#' Calculated derived variables from downloaded products for ROMS tool
#' 
#' This function is specifically built for the ROMS tool based on ROMS products. Other functions are available for processing covariates for other tools.
#'
#' @param dir The directory from which to read and write derived variables.
#' @param variable Name of derived variable of interest.
#' @param savename The file name to save the derived raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#'
#' @return A geoTIFF file is exported locally to the directories specified in the function.
#' 
calc_derived_vars_ROMS = function(dir, variable, savename, get_date) {
  
  
  if (variable == 'sst_sd') {  # Calculate SST_sd
    
    sst_sd <- rast(glue("{dir}/sst_{get_date}.tiff")) |> 
      focal(w = matrix(1, nrow = 7, ncol = 7), fun = sd, na.rm = TRUE, pad = TRUE)
    writeRaster(sst_sd, glue("{dir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
    
  } else if (variable == 'ssh_sd') {  # Calculate SSH_sd
    
    ssh_sd <- rast(glue("{dir}/ssh_{get_date}.tiff")) |> 
      focal(w = matrix(1, nrow = 7, ncol = 7), fun = sd, na.rm = TRUE, pad = TRUE)
    writeRaster(ssh_sd, glue("{dir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
    
    } else if (variable == 'EKE') {  # Calculate EKE
    
    su <- rast(glue("{dir}/su_{get_date}.tiff"))
    sv <- rast(glue("{dir}/sv_{get_date}.tiff"))
    
    eke <- 0.5 * (su^2 + sv^2) |> 
      log()
    writeRaster(eke, glue("{dir}/{savename}_{get_date}.tiff"), overwrite = TRUE)
    
    } else {
      stop("`variable` must be one of either 'sst_sd', 'ssh_sd' or 'EKE' when `tool = 'ROMS'`.")
    }
  
}
