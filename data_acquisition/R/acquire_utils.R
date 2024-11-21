
#' Functions to acquire environmental data from ERDDAP
#'
#' Download data as netCDF file from the ERDDAP server given url and variable name.
#'
#' @param ncdir_erddap A directory to store the downloaded file.
#' @param url_erddap The url from which to download the data from ERDDAP.
#' @param variable_erddap The name for the variable of interest.
#' @param savename_erddap The file name to save the downloaded netCDF.
#'
#' @return A netCDF file for relevant data is downloaded locally to the directories specified in the function.
#'
#' @export
download_erddap = function(ncdir_erddap, url_erddap, variable_erddap, savename_erddap) {

  # Define file path
  out_file = glue("{ncdir_erddap}/{savename_erddap}.nc")

  # Download data
  GET(url_erddap, write_disk(out_file, overwrite = TRUE))

}


#' Functions to acquire environmental data from CMEMS
#'
#' Download data as netCDF file from the CMEMS server given url and variable name.
#'
#' @param path_copernicus_marine_toolbox File path to locally stored version of Copernicus Marine Toolbox.
#' @param ncdir_cmems Directory to which netCDF files are saved.
#' @param product_cmems Product name of interest from CMEMS.
#' @param variable_cmems Variable name of interest from relevant CMEMS product.
#' @param savename_cmems The file name to save the downloaded netCDF.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param var_depth_min Minimum depth for which to extract values.
#' @param var_depth_max Maximum depth for which to extract values.
#'
#' @return A netCDF file for relevant data is downloaded locally to the directories specified in the function.
#'
#' @export
download_cmems = function(path_copernicus_marine_toolbox, ncdir_cmems, product_cmems,
                          variable_cmems, savename_cmems, get_date, var_depth_min,
                          var_depth_max) {

  # Write code from copernicusmarine via CLI
  command <- glue("{path_copernicus_marine_toolbox} subset -i {product_cmems} \
                  -t {get_date} -T {get_date} \
                  -z {var_depth_min}. -Z {var_depth_max}. \
                  --variable {variable_cmems} \
                  -o {ncdir_cmems} -f {savename_cmems} --force-download")

  # Run command
  system2(command)



}


#' Functions to acquire environmental data from ROMS THREDDS server
#'
#' Download data as netCDF file from the ROMS THREDDS server given url and variable name.
#'
#' @param ncdir_roms Directory to which netCDF files are saved.
#' @param variable_roms The name for the variable of interest.
#' @param savename_roms The file name to save the downloaded netCDF.
#' @param get_date Date of interest in YYYY-MM-DD format.
#'
#' @return A netCDF file for relevant data is downloaded locally to the directories specified in the function.
#'
#' @export
download_roms = function(ncdir_roms, variable_roms, savename_roms, get_date) {

  # Define number of days since ref date (2011-01-02) for url index
  ref_date <- dmy('02-01-2011')
  new_date <- as.Date(get_date)
  days <- as.numeric(difftime(new_date, ref_date))

  # Define url for data download
  my_url <- glue("https://oceanmodeling.ucsc.edu/thredds/dodsC/ccsra_2016a_phys_agg_derived_vars/fmrc/CCSRA_2016a_Phys_ROMS_Derived_Variables_Aggregation_best.ncd?{variable_roms}[{days}:1:{days}][0:1:180][0:1:185],lat_rho[0:1:180][0:1:185],lon_rho[0:1:180][0:1:185],time[0:1:1]")

  # Download data and open as R object
  nc.data <- nc_open(my_url)

  lat <- ncvar_get(nc.data, 'lat_rho') %>%
    as.numeric()
  lon <- ncvar_get(nc.data, 'lon_rho') %>%
    as.numeric()
  var <- ncvar_get(nc.data, variable_roms) %>%
    as.numeric()

  # Transform into {terra} SpatRaster object
  roms_df <- data.frame(x = lon,
                        y = lat,
                        z = var)
  roms_ras <- rast(roms_df, type = "xyz", crs = "+proj=longlat +ellips=WGS84")

  # Export as netCDF file
  writeCDF(roms_ras, glue("{ncdir_roms}/{savename_roms}.nc"), varname = variable_roms, overwrite = TRUE)

    }

