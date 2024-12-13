
# Script for downloading ERDDAP data using GitHub Actions workflow

library(dplyr)
library(lubridate)
library(glue)
library(terra)
library(httr)  ## to use GET command for downloading ERDDAP data

source("data_acquisition/R/acquire_utils.R")


# Load metadata
# meta <- read_csv("docs/model_metadata.csv")

# Define output directories
ncdir_erddap = "data_acquisition/netcdfs/erddap_ncdfs"

# Define date of interest
get_date <- Sys.Date() - 7




################
#### erddap ####
################
# each erddap product has a distinct url set up - e.g. some have time slots, some do lat first lon second, some do the reverse. Not sure how to build it within the function without having it break across products

# Define info for SST
product_erddap = "noaacwBLENDEDsstDNDaily"
variable_erddap = "analysed_sst"
savename_erddap = glue("{product_erddap}_{variable_erddap}_{get_date}")

url_erddap = glue("https://coastwatch.noaa.gov/erddap/griddap/{product_erddap}.nc?{variable_erddap}%5B({get_date}T12:00:00Z):1:({get_date}T12:00:00Z)%5D%5B(-89.99):1:(89.99)%5D%5B(-179.99):1:(180.0)%5D")


# Download netCDF if available
if (!http_error(url_erddap)) {
  download_erddap(ncdir_erddap, url_erddap, variable_erddap, savename_erddap)
} else {
  message(glue("{variable_erddap} from ERDDAP not available {get_date}"))
}




# Define info for wind
product_erddap = "erdQCwindproducts1day"
variable_erddap = "wind_v"
savename_erddap = glue("{product_erddap}_{variable_erddap}_{get_date}")

url_erddap = glue("https://coastwatch.pfeg.noaa.gov/erddap/griddap/{product_erddap}.nc?{variable_erddap}%5B({get_date}T12:00:00Z):1:({get_date}T12:00:00Z)%5D%5B(10.0):1:(10.0)%5D%5B(60):1:(10)%5D%5B(-150):1:(-100)%5D")



# Download netCDF if available
if (!http_error(url_erddap)) {
  download_erddap(ncdir_erddap, url_erddap, variable_erddap, savename_erddap)
} else {
  message(glue("{variable_erddap} from ERDDAP not available {get_date}"))
}




# Define info for Chl-a
product_erddap = "nesdisVHNnoaaSNPPnoaa20NRTchlaGapfilledDaily"
variable_erddap = "chlor_a"
savename_erddap = glue("{product_erddap}_{variable_erddap}_{get_date}")

url_erddap = glue("https://coastwatch.pfeg.noaa.gov/erddap/griddap/{product_erddap}.nc?{variable_erddap}%5B({get_date}T00:00:00Z):1:({get_date}T00:00:00Z)%5D%5B(0):1:(0)%5D%5B(60):1:(10)%5D%5B(-150):1:(-100)%5D")



# Download netCDF if available
if (!http_error(url_erddap)) {
  download_erddap(ncdir_erddap, url_erddap, variable_erddap, savename_erddap)
} else {
  message(glue("{variable_erddap} from ERDDAP not available {get_date}"))
}
