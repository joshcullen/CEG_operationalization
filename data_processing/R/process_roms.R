
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

# Define date of interest
get_date <- Sys.Date() - 8

# Define raster template
template_roms <- rast("data_processing/ROMS/static/template.tiff")



########################################################
### Process and resample data for Top Predator Watch ###
########################################################

# Prepare metadata info for I/O
meta_roms <- meta |> 
  filter(model == 'ROMS_lbst',
         category != 'derived',
         data_type != 'Other') |> 
  mutate(filename = glue("roms_{variable}_{get_date}.nc")) |> 
  split(~variable)



# Process raster layers
walk(meta_roms,
     ~process_vars(infile = .x$filename,
                   indir = ncdir_roms,
                   variable = .x$variable,
                   outdir = outdir_roms,
                   savename = .x$model_var_name,
                   get_date = get_date,
                   template = template_roms,
                   tool = "ROMS"),
     .progress = TRUE
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


# Calculate derived variables
walk(roms_meta_derived,
     ~calc_derived_vars(dir = outdir_roms,
                        variable = .x$variable,
                        savename = .x$model_var_name,
                        get_date = get_date,
                        tool = "ROMS"),
     .progress = TRUE
)
