
### Example script for downloading environmental data ###

# path <- "/Users/heatherwelch/Dropbox/Josh/Openscapes/github/CEG_operationalization" ## no more separate source_path... scripts + products in one repo
path_copernicus_marine_toolbox = "/Users/heatherwelch/miniforge3/envs/copernicusmarine/bin/copernicusmarine"
# path_copernicus_marine_toolbox = "~/miniconda3/envs/copernicusmarine/bin/copernicusmarine"

source("load_libs.R")
source("data_acquisition/R/acquire_utils.R")

ncdir_erddap = "data_acquisition/netcdfs/erddap_ncdfs"
ncdir_cmems = "data_acquisition/netcdfs/cmems_ncdfs"
ncdir_roms = "data_acquisition/netcdfs/roms_ncdfs"

get_date = "2024-10-02" 
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

# Create list of data products, variables, and exported file names
cmems_product_list <- list(list(productID = "cmems_mod_glo_phy_anfc_0.083deg_P1D-m",
                                variable = "mlotst"),
                           list(productID = "cmems_mod_glo_phy-thetao_anfc_0.083deg_P1D-m",
                                variable = "thetao")) |> 
  map_depth(.depth = 1,
            .f = function(z) {
              filename <- list(savename = glue("{z$productID}_{z$variable}_{get_date}"))
              append(z, filename)  #append filename to end of current lists
              }
            )


tryCatch(
  expr ={
    
    # Download netCDF files if available
    purrr::map(cmems_product_list,
               ~download_cmems(path_copernicus_marine_toolbox,
                               ncdir_cmems,
                               .x$productID, 
                               .x$variable,
                               .x$savename,
                               get_date))

  },
error = function(e){
  message(glue("{variable_cmems} from CMEMS not available {get_date}"))
  print(e)
}
)


##############
#### roms ####
##############

variable_roms = "sst"
savename_roms = glue("roms_{variable_roms}_{get_date}")

tryCatch(
  expr ={
download_roms(ncdir_roms, variable_roms, savename_roms, get_date)

  },
error = function(e){
  message(glue("{variable_roms} from ROMS not available {get_date}"))
  print(e)
}
)
