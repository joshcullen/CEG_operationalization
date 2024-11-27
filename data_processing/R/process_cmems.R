
# Script for downloading CMEMS data using GitHub Actions workflow

library(glue)
library(terra)
library(dplyr)
library(purrr)
library(readr)
library(lubridate)

source("data_processing/R/process_utils.R")


# Load metadata
meta <- read_csv("docs/model_metadata.csv")

# Define paths
ncdir_TopPred <- "data_acquisition/netcdfs/cmems_ncdfs"
outdir_TopPred <- "data_processing/TopPredatorWatch/rasters"

# Define date of interest
get_date <- Sys.Date() - 7

# Define raster template
template_TopPred <- rast("data_processing/TopPredatorWatch/static/template.tiff")



########################################################
### Process and resample data for Top Predator Watch ###
########################################################

# Prepare metadata info for I/O
meta_TopPred <- meta |> 
  filter(data_type == 'CMEMS',
         category != 'derived' | is.na(category)) |> 
  mutate(savename = case_when(!variable %in% c('ugosa','vgosa') ~ glue('{model_var_name}'),
                              TRUE ~ glue('{variable}')),
         filename = glue("{product}_{variable}_{get_date}.nc")
  ) |> 
  split(~variable)


# Process raster layers
walk(meta_TopPred,
     ~process_vars(infile = .x$filename,
                   indir = ncdir_TopPred,
                   variable = .x$variable,
                   outdir = outdir_TopPred,
                   savename = .x$savename,
                   get_date = get_date,
                   template = template_TopPred,
                   tool = "TopPredatorWatch"),
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


# Calculate derived variables
walk(TopPred_meta_derived,
     ~calc_derived_vars(dir = outdir_TopPred,
                        variable = .x$variable,
                        savename = .x$savename,
                        get_date = get_date,
                        tool = "TopPredatorWatch"),
     .progress = TRUE
)
