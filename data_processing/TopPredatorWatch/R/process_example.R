
### Example script for post-processing environmental data ###

library(glue)
library(terra)
library(tidyverse)  ## 2.0.0
library(sf)

source("data_processing/TopPredatorWatch/R/process_utils.R")


# Load metadata
meta <- read_csv("docs/model_metadata.csv")

# Define paths
ncdir_cmems <- "data_acquisition/netcdfs/cmems_ncdfs"
outdir_cmems <- "data_processing/TopPredatorWatch/rasters"

# Define date of interest
get_date <- Sys.Date()

# Define raster template
template <- rast("data_processing/TopPredatorWatch/static/template.tiff")



#######################################
### Process and resample CMEMS data ###
#######################################

# Prepare metadata info for I/O
meta_cmems <- meta |> 
  filter(data_type == 'CMEMS',
         category != 'derived' | is.na(category)) |> 
  mutate(savename = case_when(!variable %in% c('ugosa','vgosa') ~ glue('{model_var_name}'),
                              TRUE ~ glue('{variable}'))
         ) |> 
  split(~variable) |> 
  map_depth(.depth = 1,
            .f = function(z) {
              z$filename <- glue("{z$product}_{z$variable}_{get_date}.nc")
              
              return(z)
            }
  )


# Process raster layers
walk(meta_cmems,
    ~process_vars(infile = .x$filename,
                  indir = ncdir_cmems,
                  variable = .x$variable,
                  outdir = outdir_cmems,
                  savename = .x$savename,
                  get_date = get_date,
                  template = template,
                  tool = "TopPredatorWatch"),
    .progress = TRUE
    )



###############################################
### Generate derived covars from CMEMS data ###
###############################################

# Prepare metadata info for I/O
cmems_meta_derived <- meta |> 
  filter(data_type == 'CMEMS',
         category == 'derived') |> 
  mutate(savename = glue('{model_var_name}')) |> 
  split(~variable)


# Calculate derived variables
walk(cmems_meta_derived,
     ~calc_derived_vars(dir = outdir_cmems,
                   variable = .x$variable,
                   savename = .x$savename,
                   get_date = get_date,
                   tool = "ROMS"),
     .progress = TRUE
)
