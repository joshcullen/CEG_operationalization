
### Example script for making model predictions and generating outputs ###

library(glue)
library(terra)
library(tidyverse)  ## 2.0.0
library(sf)
library(gbm)
library(giscoR)
library(rnaturalearth)
library(pals)

source("model_prediction/R/predict_utils.R")


# Define base directory for model prediction
dyn_rast_dir_TopPred <- "data_processing/TopPredatorWatch/rasters"
pred_dir_TopPred <- "model_prediction/TopPredatorWatch"
static_rast_dir_TopPred <- glue("{pred_dir_TopPred}/static/rasters")
pred_rast_dir_TopPred <- glue("{pred_dir_TopPred}/rasters")
pred_img_dir_TopPred <- glue("{pred_dir_TopPred}/img")

dyn_rast_dir_ROMS <- "data_processing/ROMS/rasters"
pred_dir_ROMS <- "model_prediction/ROMS"
static_rast_dir_ROMS <- glue("{pred_dir_ROMS}/static/rasters")
pred_rast_dir_ROMS <- glue("{pred_dir_ROMS}/rasters")
pred_img_dir_ROMS <- glue("{pred_dir_ROMS}/img")


# Define date of interest
get_date <- Sys.Date()




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
purrr::pmap(list(mod.list_TopPred,
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






#####################################################
### Create predictions and products for ROMS tool ###
#####################################################

# Import model objects
mod.files_ROMS <- list.files(path = glue("{pred_dir_ROMS}/static/models"),
                                pattern = "*.rds", full.names = TRUE)
mod.list_ROMS <- purrr::map(mod.files_ROMS, readRDS)


# Import bounding boxes per species
# bbox.files_ROMS <- list.files(path = glue("{pred_dir_ROMS}/static/bbox"),
#                                  pattern = "leatherbackTurtle_TOPP.fgb", full.names = TRUE)
# bbox.list_ROMS <- purrr::map(bbox.files_ROMS, st_read, quiet = TRUE)


# Create name for saving products
savename_ROMS <- "leatherbackTurtle"


# Make prediction
purrr::pmap(list(mod.list_ROMS,
                 savename_ROMS),
            ~predict_models(
              dyn_rast_dir = dyn_rast_dir_ROMS,
              static_rast_dir = static_rast_dir_ROMS,
              savename = ..2,
              get_date = get_date,
              mod = ..1,
              pred_rast_dir = pred_rast_dir_ROMS,
              tool = "ROMS"
            ))

# Create map from prediction
purrr::walk(savename_ROMS,
           ~make_png(
             pred_rast_dir = pred_rast_dir_ROMS,
             get_date = get_date,
             savename = .x,
             pred_img_dir = pred_img_dir_ROMS,
             tool = "ROMS"
           ))
