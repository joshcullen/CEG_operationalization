
# Script for processing ROMS data using GitHub Actions workflow

library(glue)
library(terra)
library(dplyr)
library(purrr)
library(readr)
library(lubridate)
library(lunar)

source("data_processing/R/process_utils.R")


# Load metadata
meta <- read_csv("docs/model_metadata.csv")

# Define paths
ncdir_roms <- "data_acquisition/netcdfs/roms_ncdfs"
outdir_roms <- "data_processing/ROMS/rasters"

# Define current date
# get_date <- Sys.Date() - 7
get_date <- as_date("2024-11-29")

# Define dates of interest (related to 4-day lag from ROMS server)
dates <- get_date - 0:5

# Define raster template
template_roms <- rast("data_processing/ROMS/static/template.tiff")



########################################################
### Process and resample data for Top Predator Watch ###
########################################################

# Map workflow across date range
walk(dates, function(z){
  
  cat(glue("Processing data for {z}"))
  
  # Prepare metadata info for I/O
  meta_roms <- meta |> 
    filter(model == 'ROMS_lbst',
           category != 'derived',
           data_type != 'Other') |> 
    mutate(filename = glue("roms_{variable}_{z}.nc")) |> 
    split(~variable)
  
  
  
  tryCatch(
    expr ={
      # Process raster layers
      walk(meta_roms,
           ~process_vars(infile = .x$filename,
                         indir = ncdir_roms,
                         variable = .x$variable,
                         outdir = outdir_roms,
                         savename = .x$model_var_name,
                         get_date = z,
                         template = template_roms,
                         tool = "ROMS"),
           .progress = TRUE
      )
    },
    error = function(e){
      message(glue("Data from ROMS not available {z}"))
      print(e)
    }
  )
  
  
  #############################################
  ### Generate derived covars for ROMS tool ###
  #############################################
  
  # Prepare metadata info for I/O
  roms_meta_derived <- meta |> 
    filter(model == 'ROMS_lbst',
           category == 'derived',
           data_type == 'ROMS') |> 
    split(~variable)
  
  
  tryCatch(
    expr ={
      # Calculate derived variables
      walk(roms_meta_derived,
           ~calc_derived_vars(dir = outdir_roms,
                              variable = .x$variable,
                              savename = .x$model_var_name,
                              get_date = z,
                              tool = "ROMS"),
           .progress = TRUE
      )
    },
    error = function(e){
      message(glue("Data from ROMS not available {z}"))
      print(e)
    }
  )
  
})
