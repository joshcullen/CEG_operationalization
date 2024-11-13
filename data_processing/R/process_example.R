
### Example script for post-processing environmental data ###

library(glue)
library(terra)
library(tidyverse)  ## 2.0.0
library(sf)
library(lunar)

source("data_processing/R/process_utils.R")


# Load metadata
meta <- read_csv("docs/model_metadata.csv")

# Define paths
ncdir_TopPred <- "data_acquisition/netcdfs/cmems_ncdfs"
outdir_TopPred <- "data_processing/TopPredatorWatch/rasters"
ncdir_roms <- "data_acquisition/netcdfs/roms_ncdfs"
outdir_roms <- "data_processing/ROMS/rasters"

# Define date of interest
get_date <- Sys.Date()

# Define raster template
template_TopPred <- rast("data_processing/TopPredatorWatch/static/template.tiff")
template_roms <- rast("data_processing/ROMS/static/template.tiff")



########################################################
### Process and resample data for Top Predator Watch ###
########################################################

# Prepare metadata info for I/O
meta_TopPred <- meta |> 
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






###################################
### Resample data for ROMS tool ###
###################################

# Prepare metadata info for I/O
meta_roms <- meta |> 
  filter(model == 'ROMS_lbst',
         category != 'derived',
         data_type != 'Other') |> 
  split(~variable) |> 
  map_depth(.depth = 1,
            .f = function(z) {
              z$filename <- glue("roms_{z$variable}_{get_date}.nc")
              
              return(z)
            }
  )


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
