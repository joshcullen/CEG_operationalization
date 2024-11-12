
### Example script for making model predictions and generating outputs ###

library(glue)
library(terra)
library(tidyverse)  ## 2.0.0
library(sf)
library(gbm)
library(giscoR)
library(pals)

source("model_prediction/TopPredatorWatch/R/predict_utils.R")


# Define base directory for model prediction
pred_dir <- "model_prediction/TopPredatorWatch"
dyn_rast_dir <- "data_processing/TopPredatorWatch/rasters"
static_rast_dir <- glue("{pred_dir}/static/rasters")
pred_rast_dir <- glue("{pred_dir}/rasters")
pred_img_dir <- glue("{pred_dir}/img")


# Define date of interest
get_date <- Sys.Date()


# Import model objects
mod.files <- list.files(path = glue("{pred_dir}/static/models"), pattern = "*.rds", full.names = TRUE)
mod.list <- purrr::map(mod.files, readRDS)


# Import bounding boxes per species
bbox.files <- list.files(path = glue("{pred_dir}/static/bbox"),
                         pattern = "leatherbackTurtle_TOPP.fgb", full.names = TRUE)
bbox.list <- purrr::map(bbox.files, st_read, quiet = TRUE)


# Create name for saving products
savename <- str_remove(list.files(path = glue("{pred_dir}/static/bbox"),
                                  pattern = "leatherbackTurtle_TOPP.fgb"),
                       "_TOPP.fgb|_Dallas.fgb")


# Make prediction
purrr::pmap(list(mod.list,
                 bbox.list,
                 savename),
            ~predict_models(
              dyn_rast_dir = dyn_rast_dir,
              static_rast_dir = static_rast_dir,
              savename = ..3,
              get_date = get_date,
              bbox = ..2,
              mod = ..1,
              pred_rast_dir = pred_rast_dir
            ))

# Create map from prediction
purrr::map(savename,
           ~make_png(
             pred_rast_dir = pred_rast_dir,
             get_date = get_date,
             savename = .x,
             pred_img_dir = pred_img_dir
           ))
