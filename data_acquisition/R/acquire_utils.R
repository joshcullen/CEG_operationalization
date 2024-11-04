# functions to acquire environmental data from ERDDAP, ROMS THREDDS, CMEMS

download_erddap=function(ncdir_erddap,url_erddap,variable_erddap,savename_erddap){
  out_file = glue("{ncdir_erddap}/{savename_erddap}.nc")
  f = CFILE(out_file,mode="wb")
  curlPerform(url=url_erddap,writedata=f@ref,noprogress=FALSE, .opts = RCurl::curlOptions(ssl.verifypeer=FALSE))
  close(f)
  
}

download_cmems=function(path_copernicus_marine_toolbox,ncdir_cmems,product_cmems,variable_cmems,savename_cmems,get_date){
  command <- glue("{path_copernicus_marine_toolbox} subset -i {product_cmems} -t {get_date} -T {get_date} --variable {variable_cmems} -o {ncdir_cmems} -f {savename_cmems} --force-download")   
  system(command, intern = TRUE)
  
}

download_roms=function(ncdir_roms,variable_roms,savename_roms,get_date){ 

  
  ref_date <- dmy('02-01-2011')
  new_date <- as.Date(get_date)
  days <- as.numeric(difftime(new_date, ref_date))
  
  my_url = glue("https://oceanmodeling.ucsc.edu/thredds/dodsC/ccsra_2016a_phys_agg_derived_vars/fmrc/CCSRA_2016a_Phys_ROMS_Derived_Variables_Aggregation_best.ncd?{variable_roms}[{days}:1:{days}][0:1:180][0:1:185],lat_rho[0:1:180][0:1:185],lon_rho[0:1:180][0:1:185],time[0:1:1]")
  nc.data=nc_open(my_url) 
  
  lat <- ncvar_get(nc.data,'lat_rho') %>% as.numeric()
  lon <- ncvar_get(nc.data,'lon_rho')  %>% as.numeric()
  var <- ncvar_get(nc.data, variable_roms) %>% as.numeric()

  roms_df=data.frame(x=lon,y=lat,z=var)
  roms_ras=rast(roms_df,type="xyz",crs="+proj=longlat +ellips=WGS84")
  
  writeCDF(roms_ras, glue("{ncdir_roms}/{savename_roms}.nc"), varname=variable_roms,overwrite=T)
  
    }
