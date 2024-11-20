
# Test script for using GitHub Actions workflow

library(dplyr)
library(purrr)
library(readr)
library(glue)

source("data_acquisition/R/acquire_utils.R")


# Load metadata
meta <- read_csv("docs/model_metadata.csv")

# Define output directories
ncdir_cmems = "data_acquisition/netcdfs/cmems_ncdfs"
ncdir_roms = "data_acquisition/netcdfs/roms_ncdfs"

# Define date of interest
get_date <- Sys.Date() - 7




###############
#### cmems ####
###############

# Define CMEMS metadata object
meta_cmems <- meta |>
  filter(data_type == 'CMEMS',
         category != 'derived' | is.na(category)) |>
  mutate(var_depth_min = case_when(variable != 'o2' ~ 0,
                                   TRUE ~ 200),
         var_depth_max = case_when(variable %in% c('analysed_sst','CHL','mlotst') ~ 0,
                                   TRUE ~ 200))


# Transform to list and add exported file names
cmems_product_list <- meta_cmems |>
  mutate(savename = glue("{product}_{variable}_{get_date}")) |>
  split(~variable)


tryCatch(
  expr ={

    # Download netCDF files if available
    purrr::map(cmems_product_list[4],
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
    message(glue("{variable_cmems} from CMEMS not available {get_date}"))
    print(e)
  }
)
