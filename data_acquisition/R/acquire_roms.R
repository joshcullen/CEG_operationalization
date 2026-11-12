
# Script for downloading ROMS data using GitHub Actions workflow

library(dplyr)
library(purrr)
library(readr)
library(lubridate)
library(glue)
library(terra)
library(ncdf4)
library(httr)

source("data_acquisition/R/acquire_utils.R")



##########################################
### Check if ROMS THREDDS server is up ###
##########################################

# Ping the THREDDS server before starting the workflow
thredds_url <- "https://oceanmodeling.ucsc.edu/thredds/dodsC/ccsra_2016a_phys_agg_zlevs/fmrc/CCSRA_2016a_Phys_ROMS_z-level_(depth)_Aggregation_best.ncd.html"

server_is_up <- tryCatch({
  res <- httr::HEAD(thredds_url, httr::timeout(15))
  httr::status_code(res) == 200
}, error = function(e) FALSE)

gh_env <- Sys.getenv("GITHUB_ENV")

if (!server_is_up) {
  message("THREDDS server is currently down. Halting workflow gracefully.")
  if (gh_env != "") cat("PROCEED=false\n", file = gh_env, append = TRUE)
  
  # Exit cleanly with status 0 so GitHub Actions doesn't register a "failed" workflow
  quit(save = "no", status = 0, runLast = FALSE) 

}








##########################
### Set up environment ###
##########################

# Load metadata
meta <- read_csv("metadata/model_metadata.csv")

# Define output directories
ncdir_roms = "data_acquisition/netcdfs/roms_ncdfs"

# Define current date
get_date <- Sys.Date() - 1
# get_date <- as_date("2024-11-29")

# Define dates of interest (related to 4-day lag from ROMS server)
dates <- get_date - 0:5


# Initialize a flag to track if ANY data was successfully downloaded
data_downloaded <- FALSE



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
      # If the above succeeds without error, mark flag as TRUE
      data_downloaded <<- TRUE
      
    },
    error = function(e){
      message(glue("Data from ROMS not available {z}"))
      print(e)
    }
  )
  
})


# Evaluate the "download" flag
gh_env <- Sys.getenv("GITHUB_ENV")

if (!data_downloaded) {
  message("No ROMS data was available to download for any dates. Halting workflow gracefully.")
  if (gh_env != "") cat("PROCEED=false\n", file = gh_env, append = TRUE)
  quit(save = "no", status = 0, runLast = FALSE) 
} else {
  message("ROMS data acquired successfully.")
  if (gh_env != "") cat("PROCEED=true\n", file = gh_env, append = TRUE)
}

