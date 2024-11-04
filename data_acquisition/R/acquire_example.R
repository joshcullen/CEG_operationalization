library(glue)

path <- "/Users/heatherwelch/Dropbox/Josh/Openscapes/github/CEG_operationalization" ## no more separate source_path... scripts + products in one repo
path_copernicus_marine_toolbox = "/Users/heatherwelch/miniforge3/envs/copernicusmarine/bin/copernicusmarine"

source(glue("{path}/load_libs.R"))
source(glue("{path}/data_acquisition/R/acquire_utils.R"))

ncdir_erddap=glue("{path}/data_acquisition/netcdfs/erddap_ncdfs")
ncdir_cmems=glue("{path}/data_acquisition/netcdfs/cmems_ncdfs")
ncdir_roms=glue("{path}/data_acquisition/netcdfs/roms_ncdfs")

get_date="2024-10-01" 
# when this script is operational, I think we'll want it to check for new envt data each day from launch day to sys.date (similar to the OPC tool)
# so that it's always trying to backfill missing envt data

## erddap ####
# each erddap product has a distinct url set up - e.g. some have time slots, some do lat first lon second, some do the reverse. Not sure how to build it within the function without having it break across products
# erddap only allows 2GB requests at once - one day of jplMURSST41 is ~5 GB. Dividing latitudes into 5 separate downloads 
# testing with small longitude width because erddap takes so long
# this is so chaotic - any suggestions for cleaning it up?

product_erddap="jplMURSST41"
variable_erddap="analysed_sst"

tryCatch(
  expr ={
    
## download 10 lat chunks
# 180 degrees long / 10 chunks = 18 degrees long per chunk
for(i in 0:9){
  start_lat=-89.99+(18*i)
  end_lat=-89.99+(18*(i+1))
  if(i==9){end_lat=89.99}
  
  print(glue("start = #{i}:{start_lat}"))
  print(glue("end = #{i}:{end_lat}"))
  
savename_erddap=glue("{product_erddap}_{variable_erddap}_{get_date}_{start_lat}_{end_lat}")
url_erddap=glue("https://coastwatch.pfeg.noaa.gov/erddap/griddap/{product_erddap}.nc?{variable_erddap}%5B({get_date}T09:00:00Z):1:({get_date}T09:00:00Z)%5D%5B({start_lat}):1:({end_lat})%5D%5B(-179.99):1:(-170.0)%5D") # partial lon
# url_erddap=glue("https://coastwatch.pfeg.noaa.gov/erddap/griddap/{product_erddap}.nc?{variable_erddap}%5B({get_date}T09:00:00Z):1:({get_date}T09:00:00Z)%5D%5B({start_lat}):1:({end_lat})%5D%5B(-179.99):1:(180.0)%5D")  # full lon
download_erddap(ncdir_erddap,url_erddap,variable_erddap,savename_erddap)
}

## merge chunks
erddap_ras_list=list.files(ncdir_erddap,pattern=glue("{product_erddap}_{variable_erddap}_{get_date}"),full.names = T) 
erddap_ras=erddap_ras_list%>% 
  purrr::map(.,
           ~rast(.)) %>% 
  sprc() %>% 
  merge()

## write out merged file and delete lat chunks
writeCDF(erddap_ras, glue("{ncdir_erddap}/{product_erddap}_{variable_erddap}_{get_date}.nc"), varname=variable_erddap,  unit="degree_C",overwrite=T)
file.remove(erddap_ras_list)

  },
error = function(e){
  message(glue("{variable_erddap} from ERDDAP not available {get_date}"))
  print(e)
}
)

## cmems ####
# thinking about scaling this up to multiple cmems variables - I saw your map code in the top predator watch tool
# is there a way to dynamically glue as you define a list, e.g. so savename_cmems could be defined during list creation?

product_cmems = "cmems_mod_glo_phy_anfc_0.083deg_P1D-m"
variable_cmems <- "mlotst"
savename_cmems=glue("{product_cmems}_{variable_cmems}_{get_date}")

tryCatch(
  expr ={
    
download_cmems(path_copernicus_marine_toolbox,ncdir_cmems,product_cmems,variable_cmems,savename_cmems,get_date)
    
  },
error = function(e){
  message(glue("{variable_cmems} from CMEMS not available {get_date}"))
  print(e)
}
)

## roms ####
variable_roms="sst"
savename_roms=glue("roms_{variable_roms}_{get_date}")

tryCatch(
  expr ={
download_roms(ncdir_roms,variable_roms,savename_roms,get_date)

  },
error = function(e){
  message(glue("{variable_roms} from ROMS not available {get_date}"))
  print(e)
}
)
