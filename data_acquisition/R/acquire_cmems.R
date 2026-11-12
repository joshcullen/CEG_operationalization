# Script for downloading CMEMS data using GitHub Actions workflow

library(dplyr)
library(purrr)
library(readr)
library(glue)

source("data_acquisition/R/acquire_utils.R")


# Load metadata
meta <- read_csv("metadata/model_metadata.csv")

# Define output directories
ncdir_cmems = "data_acquisition/netcdfs/cmems_ncdfs"

# Define date of interest
get_date <- Sys.Date() - 1


###############
#### cmems ####
###############

# Define CMEMS metadata object
meta_cmems <- meta |>
  filter(data_type == 'CMEMS', category != 'derived' | is.na(category)) |>
  mutate(
    var_depth_min = case_when(variable != 'o2' ~ 0, TRUE ~ 200),
    var_depth_max = case_when(
      variable %in% c('analysed_sst', 'CHL', 'mlotst') ~ 1,
      TRUE ~ 200
    )
  )

log_path <- "metadata/missing_cmems_layers.csv"  #for storing missing variable data





###################################################################
### RECOVERY STEP: Attempt to download previously missing data  ###
###################################################################

if (file.exists(log_path)) {
  missing_log <- read_csv(log_path, show_col_types = FALSE)
  
  if (nrow(missing_log) > 0) {
    message("Attempting to download previously missing CMEMS data...")
    
    # Join with metadata to get required download arguments (product, depths)
    missing_to_download <- missing_log |>
      left_join(meta_cmems |> select(variable, product, var_depth_min, var_depth_max), by = "variable")
    
    # Iterate through the missing records and attempt to download
    purrr::pwalk(
      list(missing_to_download$product, missing_to_download$variable, 
           missing_to_download$file, missing_to_download$date, 
           missing_to_download$var_depth_min, missing_to_download$var_depth_max),
      function(prod, var, fname, d, dmin, dmax) {
        
        # Remove the '.nc' extension for the savename argument
        sname <- stringr::str_remove(fname, "\\.nc$") 
        
        tryCatch({
          download_cmems(
            "/usr/share/miniconda/envs/test/bin/copernicusmarine",
            ncdir_cmems, prod, var, sname, as.Date(d), dmin, dmax
          )
        }, error = function(e) {
          # Suppress error printing here since it's already logged as missing
        })
      }
    )
    
    # Check which files were successfully recovered
    still_missing <- missing_log |>
      filter(!file.exists(glue("{ncdir_cmems}/{file}")))
    
    # Overwrite the CSV with only the remaining missing files
    write_csv(still_missing, log_path)
    
    recovered_count <- nrow(missing_log) - nrow(still_missing)
    if (recovered_count > 0) {
      message(glue("Successfully recovered {recovered_count} previously missing files."))
    } else {
      message("No previously missing files were available yet.")
    }
  }
}




####################################################
### MAIN STEP: Download current date of interest ###
####################################################

# Transform to list and add exported file names
cmems_product_list <- meta_cmems |>
  mutate(savename = glue("{product}_{variable}_{get_date[1]}")) |>
  split(~variable)


tryCatch(
  expr = {
    # Download netCDF files if available
    purrr::map(
      cmems_product_list,
      ~ download_cmems(
        "/usr/share/miniconda/envs/test/bin/copernicusmarine",
        ncdir_cmems,
        .x$product,
        .x$variable,
        .x$savename,
        get_date,
        .x$var_depth_min,
        .x$var_depth_max
      )
    )
  },
  error = function(e) {
    message(glue("{variable} from CMEMS not available {get_date}"))
    print(e)
  }
)


### Check to see if any env vars weren't downloaded
files <- map(cmems_product_list, ~{.x |> pull(savename)} |> paste0(".nc")) |> 
  list_c()

expected_filepaths <- glue("{ncdir_cmems}/{files}")

# Filter down to only the files that do not exist
missing_files <- files[!file.exists(expected_filepaths)]


if (length(missing_files) > 0) {
  
  # Extract the variable name using the metadata list
  var_pattern <- paste0(meta_cmems$variable, collapse = "|")
  missing_vars <- stringr::str_extract(missing_files, var_pattern)
  
  # Extract the date using a YYYY-MM-DD regex pattern
  missing_dates <- stringr::str_extract(missing_files, "\\d{4}-\\d{2}-\\d{2}")
  
  # Bind into a dataframe to log
  missing_log <- dplyr::tibble(
    variable = missing_vars,
    date = missing_dates,
    file = missing_files,
    time_logged = Sys.time()
  )
  
  log_path <- "metadata/missing_cmems_layers.csv"
  
  # Write to CSV (appending if it already exists to track consecutive days)
  if (file.exists(log_path)) {
    readr::write_csv(missing_log, log_path, append = TRUE)
  } else {
    readr::write_csv(missing_log, log_path)
  }
  
  message(glue::glue("Logged {length(missing_files)} missing files to {log_path}"))
  
} else {
  message("All expected CMEMS environmental variables were successfully downloaded.")
}