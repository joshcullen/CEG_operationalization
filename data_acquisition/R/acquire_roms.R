
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

# Define current date
# get_date <- Sys.Date() - 7
get_date <- as_date("2024-11-29")

# Define dates of interest (related to 4-day lag from ROMS server)
dates <- get_date - 0:5




##############
#### roms ####
##############

# Map workflow across date range
walk(dates, function(z){
  
  cat(glue("Downloading data for {z}"))
  
  # Define ROMS metadata object
  meta_roms <- meta |>
    filter(data_type == 'ROMS',
           category != 'derived')
  
  
  # Transform to list and add exported file names
  roms_product_list <- meta_roms |>
    mutate(savename = glue("roms_{variable}_{z}")) |>
    split(~variable)
  
  
  tryCatch(
    expr ={
      # Download netCDF files if available
      purrr::walk(roms_product_list,
                  ~download_roms(ncdir_roms,
                                 .x$variable,
                                 .x$savename,
                                 z))
      
    },
    error = function(e){
      message(glue("Data from ROMS not available {z}"))
      print(e)
    }
  )
  
})


