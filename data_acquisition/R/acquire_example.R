
### Example script for downloading environmental data ###

library(glue)
library(terra)
library(tidyverse)  ## 2.0.0
library(sf)
library(ncdf4) ## needed to interact with ROMS THREDDS server - rast() doesn't work
library(httr)  ## to use GET command for downloading ERDDAP data

source("data_acquisition/R/acquire_utils.R")


# path <- "/Users/heatherwelch/Dropbox/Josh/Openscapes/github/CEG_operationalization" ## no more separate source_path... scripts + products in one repo
# path_copernicus_marine_toolbox = "/Users/heatherwelch/miniforge3/envs/copernicusmarine/bin/copernicusmarine"
# path_copernicus_marine_toolbox = "~/miniconda3/envs/copernicusmarine/bin/copernicusmarine"



# Load metadata
meta <- read_csv("docs/model_metadata.csv")

ncdir_erddap = "data_acquisition/netcdfs/erddap_ncdfs"
ncdir_cmems = "data_acquisition/netcdfs/cmems_ncdfs"
ncdir_roms = "data_acquisition/netcdfs/roms_ncdfs"

get_date = "2024-11-08"
# when this script is operational, I think we'll want it to check for new envt data each day from launch day to sys.date (similar to the OPC tool)
# so that it's always trying to backfill missing envt data




################
#### erddap ####
################
# each erddap product has a distinct url set up - e.g. some have time slots, some do lat first lon second, some do the reverse. Not sure how to build it within the function without having it break across products

# Define info for product download
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
    purrr::map(cmems_product_list,
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
  message(glue("{variable_roms} from ROMS not available {get_date}"))
  print(e)
}
)
