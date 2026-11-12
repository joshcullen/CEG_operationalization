
# Script for making predictions for Top Predator Watch using GitHub Actions workflow

library(glue)
library(terra)
library(dplyr)
library(purrr)
library(stringr)
library(lubridate)
library(ggplot2)
library(readr)
library(sf)
library(gbm)
# library(giscoR)
library(rnaturalearth)
library(pals)

source("model_prediction/R/predict_utils.R")


# Define base directory for model prediction
dyn_rast_dir_TopPred <- "data_processing/TopPredatorWatch/rasters"  #dir of dynamic input data
pred_dir_TopPred <- "model_prediction/TopPredatorWatch"  #base dir for predictions
static_rast_dir_TopPred <- glue("{pred_dir_TopPred}/static/rasters")  #dir of static input data
pred_rast_dir_TopPred <- glue("{pred_dir_TopPred}/rasters")  #dir of prediction as raster
pred_img_dir_TopPred <- glue("{pred_dir_TopPred}/img")  #dir of prediction as image

# Load metadata
meta <- read_csv("metadata/model_metadata.csv")


# Define date of interest
get_date <- Sys.Date() - 1




##############################################################
### Create predictions and products for Top Predator Watch ###
##############################################################

# Import model objects
mod.files_TopPred <- list.files(path = glue("{pred_dir_TopPred}/static/models"),
                                pattern = "*.rds", full.names = TRUE)
mod.list_TopPred <- purrr::map(mod.files_TopPred, readRDS)


# Import bounding boxes per species
bbox.files_TopPred <- list.files(path = glue("{pred_dir_TopPred}/static/bbox"),
                                 pattern = "leatherbackTurtle_TOPP.fgb", full.names = TRUE)
bbox.list_TopPred <- purrr::map(bbox.files_TopPred, st_read, quiet = TRUE)


# Create name for saving products
savename_TopPred <- str_remove(list.files(path = glue("{pred_dir_TopPred}/static/bbox"),
                                          pattern = "leatherbackTurtle_TOPP.fgb"),
                               "_TOPP.fgb|_Dallas.fgb")


# Print R objects
# print(mod.list_TopPred)
# print(bbox.list_TopPred)
# print(savename_TopPred)
# print(get_date)



######################################################
### Check that all covars available for `get_date` ###
######################################################

# Define dynamic model covars
dyn_vars <- meta |> 
  filter(data_type == 'CMEMS' & !is.na(model_var_name) | variable == "day") |> 
  pull(model_var_name) |> 
  unique()


# Map through each dynamic variable and find the most recent file
covar_dates_used <- purrr::map_dfr(dyn_vars, function(var) {
  
  # Create a vector of dates: the target date, plus the 7 days prior
  dates_to_try <- c(get_date, get_date - 1:7)
  
  found_date <- NA
  found_file <- NA
  
  # Iterate through the dates in order
  for (i in seq_along(dates_to_try)) {
    d <- dates_to_try[i]
    
    # Construct the expected filename (assuming "{var}_{date}.nc" format)
    infile <- glue::glue("{var}_{d}.nc")
    filepath <- file.path(dyn_rast_dir_TopPred, infile)
    
    # If the file exists, lock it in and break the loop
    if (file.exists(filepath)) {
      found_date <- d
      found_file <- filepath
      break
    }
  }
  
  # Return a summary row for this variable
  data.frame(
    model_var_name = var,
    target_date = get_date,
    used_date = as_date(found_date),
    file_path = found_file,
    status = dplyr::case_when(
      is.na(found_date) ~ "Missing",
      found_date == get_date ~ "On Time",
      TRUE ~ "Fallback"
    )
  )
})

# View the log of which files and dates are being used
print(covar_dates_used)


# If any covars missing w/in 7 days, don't make prediction
if (any(covar_dates_used$status == 'Missing')) {
  
  miss <- covar_dates_used |> 
    filter(status == "Missing") |> 
    pull(model_var_name)
  
  stop(glue("Stopping model prediction. No data available within last 7 days for {miss}"))
}




# Make prediction
purrr::pwalk(list(mod.list_TopPred,
                  bbox.list_TopPred,
                  savename_TopPred),
             ~predict_models(
               dyn_rast_files = covar_dates_used$file_path,
               static_rast_dir = static_rast_dir_TopPred,
               savename = ..3,
               get_date = get_date,
               bbox = ..2,
               mod = ..1,
               pred_rast_dir = pred_rast_dir_TopPred,
               tool = "TopPredatorWatch"
             ))

# Create map from prediction
purrr::walk(savename_TopPred,
            ~make_png(
              pred_rast_dir = pred_rast_dir_TopPred,
              get_date = get_date,
              savename = .x,
              pred_img_dir = pred_img_dir_TopPred,
              tool = "TopPredatorWatch"
            ))
