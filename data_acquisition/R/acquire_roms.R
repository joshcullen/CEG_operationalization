
# Script for downloading ROMS data using GitHub Actions workflow

library(dplyr)
library(purrr)
library(readr)
library(lubridate)
library(glue)
library(terra)
library(ncdf4)

source("data_acquisition/R/acquire_utils.R")


# Load metadata
meta <- read_csv("docs/model_metadata.csv")

# Define output directories
ncdir_roms = "data_acquisition/netcdfs/roms_ncdfs"

# Define date of interest
get_date <- Sys.Date() - 7




##############
#### roms ####
##############

# Define ROMS metadata object
meta_roms <- meta |>
  filter(data_type == 'ROMS',
         category != 'derived')


# Transform to list and add exported file names
roms_product_list <- meta_roms |>
  mutate(savename = glue("roms_{variable}_{get_date}")) |>
  split(~variable)


tryCatch(
  expr ={
    # Download netCDF files if available
    purrr::map(roms_product_list,
               ~download_roms(ncdir_roms,
                              .x$variable,
                              .x$savename,
                              get_date))

  },
  error = function(e){
    message(glue("Data from ROMS not available {get_date}"))
    print(e)
  }
)
