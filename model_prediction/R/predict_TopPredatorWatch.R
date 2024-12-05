
# Script for making predictions for Top Predator Watch using GitHub Actions workflow

library(glue)
library(terra)
library(dplyr)
library(purrr)
library(stringr)
library(lubridate)
library(ggplot2)
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


# Define date of interest
get_date <- Sys.Date() - 10




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


# Make prediction
purrr::pwalk(list(mod.list_TopPred,
                  bbox.list_TopPred,
                  savename_TopPred),
             ~predict_models(
               dyn_rast_dir = dyn_rast_dir_TopPred,
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
