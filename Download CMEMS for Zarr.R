
### Download past year of CMEMS data for storag in Zarr format ###

library(dplyr)
library(purrr)
library(readr)
library(glue)
library(lubridate)
library(terra)

source("data_acquisition/R/acquire_utils.R")


# Load metadata
meta <- read_csv("metadata/model_metadata.csv")

# Define output directories
ncdir_cmems = "data_acquisition/netcdfs/cmems_ncdfs"
outdir_cmems <- "data_processing/TopPredatorWatch/rasters"

# Define raster template
template_TopPred <- rast("data_processing/TopPredatorWatch/static/template.tiff")

# Define date of interest
get_date <- c("2025-01-01", as.character(Sys.Date() - 1))




#######################
#### Download data ####
#######################

# Define CMEMS metadata object
meta_cmems <- meta |>
  filter(data_type == 'CMEMS',
         category != 'derived' | is.na(category)) |>
  mutate(var_depth_min = case_when(variable != 'o2' ~ 0,
                                   TRUE ~ 200),
         var_depth_max = case_when(variable %in% c('analysed_sst','CHL','mlotst') ~ 1,
                                   TRUE ~ 200))


# Transform to list and add exported file names
cmems_product_list <- meta_cmems |>
  mutate(savename = glue("{product}_{variable}_{get_date[1]}_{get_date[2]}")) |>
  split(~variable)


tryCatch(
  expr ={

    # Download netCDF files if available
    purrr::map(cmems_product_list,
               ~download_cmems("copernicusmarine",
                               ncdir_cmems,
                               .x$product,
                               .x$variable,
                               .x$savename,
                               get_date,
                               .x$var_depth_min,
                               .x$var_depth_max))

  },
  error = function(e){
    message(glue("{variable} from CMEMS not available in {get_date[1]} to {get_date[2]}"))
    print(e)
  }
)




##########################################
### Process files for model prediction ###
##########################################

# Prepare metadata info for I/O
meta_TopPred <- meta |> 
  filter(data_type == 'CMEMS',
         category != 'derived' | is.na(category)) |> 
  mutate(savename = case_when(!variable %in% c('ugosa','vgosa') ~ glue('{model_var_name}'),
                              TRUE ~ glue('{variable}')),
         filename = glue("{product}_{variable}_{get_date[1]}_{get_date[2]}.nc")
  ) |> 
  split(~variable)



# Define modified version of process_vars_TopPred()
process_vars_TopPred = function(infile, indir, variable, outdir, savename, template) {
  
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
      r <- tapp(r, index = "days", fun = mean, na.rm = TRUE, cores = 6)
    }
    
    # Resample raster by template
    r2 <- resample(r, template, threads = TRUE, by_util = TRUE)  
    # time(r2) <- NULL  #prevent creation of aux.json files (associated w/ times or units)
    
    
    # Remove "no data" values added for sla, ugosa, and vgosa
    if (variable %in% c('sla','ugosa','vgosa')) {
      r2[r2 < -1000] <- NA
    }
    
    # Smooth over over 5x5 window (1.25 deg) (but not for geostrophic currents)
    if (!variable %in% c('ugosa','vgosa')) {
      
      r2_mean <- focal(r2, w = matrix(1, nrow = 5, ncol = 5), fun = mean, na.rm = TRUE)
      writeCDF(r2_mean, glue("{outdir}/{savename}.nc"), varname = variable, overwrite = TRUE)
      
    } else {
      
      # units(r2) <- NULL  #need to remove to prevent creation of .aux.json files
      
      writeCDF(r2_mean, glue("{outdir}/{savename}.nc"), varname = variable, overwrite = TRUE)
      
    }
    
  } else {
    message(glue("{infile} doesn't exist"))
  }
  
}





# Process raster layers
walk(meta_TopPred,
  ~process_vars_TopPred(infile = .x$filename,
    indir = ncdir_cmems,
    variable = .x$variable,
    outdir = outdir_cmems,
    savename = .x$savename,
    template = template_TopPred),
    .progress = TRUE
  )






######################################################
### Generate derived covars for Top Predator Watch ###
######################################################

# Prepare metadata info for I/O
TopPred_meta_derived <- meta |> 
  filter(data_type == 'CMEMS',
         category == 'derived') |> 
  mutate(savename = glue('{model_var_name}')) |> 
  split(~variable)


# Define modified version of calc_derived_vars_TopPred
calc_derived_vars_TopPred = function(dir, variable, savename) {
  
  
  if (variable == 'sst_sd') {  # Calculate SST_sd
    
    sst_sd <- rast(glue("{dir}/sst.nc")) |> 
      focal(w = matrix(1, nrow = 5, ncol = 5), fun = sd, na.rm = TRUE)
    writeCDF(sst_sd, glue("{dir}/{savename}.nc"), varname = variable, overwrite = TRUE)
    
  } else if (variable == 'eke') {  # Calculate EKE
    
    u <- rast(glue("{dir}/ugosa.nc"))
    v <- rast(glue("{dir}/vgosa.nc"))
    
    eke <- 0.5 * (u^2 + v^2)
    l.eke <- log10(eke + 0.001)
    eke_mean <- focal(l.eke, w = matrix(1, nrow = 5, ncol = 5), fun = mean, na.rm = TRUE)
    writeCDF(eke_mean, glue("{dir}/{savename}.nc"), varname = variable, overwrite = TRUE)
    
  } else {
    stop("`variable` must be one of either 'sst_sd' or 'eke' when `tool = 'TopPredatorWatch'`.")
  }
  
}




# Calculate derived variables
walk(TopPred_meta_derived,
  ~calc_derived_vars_TopPred(dir = outdir_cmems,
    variable = .x$variable,
    savename = .x$savename),
    .progress = TRUE
  )
