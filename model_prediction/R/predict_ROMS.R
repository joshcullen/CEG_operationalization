
# Script for making predictions for ROMS model using GitHub Actions workflow

library(glue)
library(terra)
library(dplyr)
library(purrr)
library(stringr)
library(lubridate)
library(ggplot2)
library(sf)
library(gbm)
library(rnaturalearth)
library(pals)

source("model_prediction/R/predict_utils.R")


# Define base directory for model prediction
dyn_rast_dir_ROMS <- "data_processing/ROMS/rasters"  #dir of dynamic input data
pred_dir_ROMS <- "model_prediction/ROMS"  #base dir for predictions
static_rast_dir_ROMS <- glue("{pred_dir_ROMS}/static/rasters")  #dir of static input data
pred_rast_dir_ROMS <- glue("{pred_dir_ROMS}/rasters")  #dir of prediction as raster
pred_img_dir_ROMS <- glue("{pred_dir_ROMS}/img")  #dir of prediction as image

# Define current date
# get_date <- Sys.Date() - 7
get_date <- as_date("2024-11-29")

# Define dates of interest (related to 4-day lag from ROMS server)
dates <- get_date - 0:5




##############################################################
### Create predictions and products for Top Predator Watch ###
##############################################################

# Import model objects
mod.files_ROMS <- list.files(path = glue("{pred_dir_ROMS}/static/models"),
                             pattern = "*.rds", full.names = TRUE)
mod.list_ROMS <- purrr::map(mod.files_ROMS, readRDS)


# Create name for saving products
savename_ROMS <- "leatherbackTurtle"


# Map workflow across date range
walk(dates, function(z){
  
  cat(glue("Processing data for {z}"))
  
  tryCatch(
    expr ={
      # Make prediction
      purrr::pmap(list(mod.list_ROMS,
                       savename_ROMS),
                  ~predict_models(
                    dyn_rast_dir = dyn_rast_dir_ROMS,
                    static_rast_dir = static_rast_dir_ROMS,
                    savename = ..2,
                    get_date = z,
                    mod = ..1,
                    pred_rast_dir = pred_rast_dir_ROMS,
                    tool = "ROMS"
                  ))
    },
    error = function(e){
      message(glue("Data from ROMS not available {z}"))
      print(e)
    }
  )

  
  tryCatch(
    expr ={
      # Create map from prediction
      purrr::walk(savename_ROMS,
                  ~make_png(
                    pred_rast_dir = pred_rast_dir_ROMS,
                    get_date = z,
                    savename = .x,
                    pred_img_dir = pred_img_dir_ROMS,
                    tool = "ROMS"
                  ))
    },
    error = function(e){
      message(glue("Data from ROMS not available {z}"))
      print(e)
    }
  )
  
})
