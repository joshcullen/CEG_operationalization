
#' Function for making predictions from BRT (and/or other) models
#' 
#' The code for generating model predictions is currently written in a format that is generalizable across multiple tools. Some additional steps may be needed based on how the models were fitted and/or if masking of environmental rasters is necessary.
#'
#' @param dyn_rast_dir File path from which to import dynamic raster layers.
#' @param static_rast_dir File path from which to import static raster layers.
#' @param savename The file name to save the derived raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param bbox An `sf` POLYGON or MULTIPOLYGON layer for which to mask rasters. Only required for TopPredatorWatch tool.
#' @param mod Model object from which to make predictions.
#' @param pred_rast_dir File path for which to export raster prediction layer.
#' @param tool Name of the tool to for data processing; 'TopPredatorWatch' or 'ROMS'.
#'
#' @return Generates and exports a predictive surface for each species of interest.
#' 
#' @export
predict_models = function(dyn_rast_dir, static_rast_dir, savename, get_date, bbox = NULL,
                          mod, pred_rast_dir, tool) {
  
  print(glue("Starting model prediction for {savename}"))
  
  # Load rasters and rename layers
  dyn_rast <- rast(list.files(dyn_rast_dir, pattern = paste(get_date), full.names = TRUE))
  dyn_names <- list.files(dyn_rast_dir, pattern = paste(get_date)) |>
    str_remove(pattern = glue("_{get_date}.tiff"))
  names(dyn_rast) <- dyn_names
  
  static_rast <- rast(list.files(static_rast_dir, full.names = TRUE))
  static_names <- list.files(static_rast_dir) |>
    str_remove(pattern = ".tiff")
  names(static_rast) <- static_names
  
  # Join rasters
  rast_stack <- c(dyn_rast, static_rast)
  
  
  # Make predictions
  pred <- switch(tool,
                 "TopPredatorWatch" = predict_models_TopPred(rast_stack = rast_stack,
                                                             bbox = bbox,
                                                             mod = mod),
                 
                 "ROMS" = predict_models_ROMS(rast_stack = rast_stack,
                                              mod = mod),
                 
                 stop("Tool must be one of either 'TopPredatorWatch' or 'ROMS'.")
  )
  
  
  # Export prediction raster
  writeRaster(pred, glue("{pred_rast_dir}/pred_{get_date}_{savename}.tiff"), overwrite = TRUE)
  
}




#' Function for making predictions from Top Predator Watch models
#'
#' @param rast_stack A SpatRaster object that contains all dynamic and static raster layers required for model prediction.
#' @param bbox An `sf` POLYGON or MULTIPOLYGON layer for which to mask rasters.
#' @param mod Model object from which to make predictions.
#'
#' @return Generates a predictive SpatRaster surface for the species of interest.
#'
predict_models_TopPred = function(rast_stack, bbox, mod) {
  
  # Mask rasters by bbox
  rast_stack2 <- terra::mask(rast_stack, bbox)
  
  # Make prediction
  pred <- predict(object = rast_stack2, model = mod, n.trees = mod$gbm.call$best.trees,
                    type = "response", na.rm = FALSE)
  pred2 <- terra::mask(pred, bbox)
  
  return(pred2)
}




#' Function for making predictions from ROMS tool model
#'
#' @param rast_stack A SpatRaster object that contains all dynamic and static raster layers required for model prediction.
#' @param mod Model object from which to make predictions.
#'
#' @return Generates a predictive SpatRaster surface for the species of interest.
#'
predict_models_ROMS = function(rast_stack, mod) {
  
  # Make prediction
  pred <- predict(object = rast_stack, model = mod, n.trees = mod$gbm.call$best.trees,
                  type = "response", na.rm = FALSE)
  
  return(pred)
}




#' Function to create images of predicted maps from the operational tools
#' 
#' May require separation into separate internal functions per tool (as for other steps), but currently left in single function for now.
#'
#' @param pred_rast_dir File path for which to import raster prediction layer.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param savename The file name to save the derived raster.
#' @param pred_img_dir File path for which to export map of prediction.
#' @param tool Name of the tool to for data processing; 'TopPredatorWatch' or 'ROMS'.
#'
#' @return Generates and exports a predictive map for each species of interest.
#' 
#' @export
make_png <- function(pred_rast_dir, get_date, savename, pred_img_dir, tool) {
  
  print(glue("Making png of {savename} prediction"))
  
  # Import prediction raster
  pred <- rast(glue("{pred_rast_dir}/pred_{get_date}_{savename}.tiff"))
  
  
  # Format date for map
  plot_date <- format(as_date(get_date), format = "%B %d %Y")
  
  pred.df <- as.data.frame(pred, xy = TRUE)
  
  # load spatial layer for country polygons
  if (tool == 'TopPredatorWatch') {
    
    world <- world <- gisco_countries |> 
      filter(NAME_ENGL != "Antarctica") |> 
      st_shift_longitude() |>
      st_crop(xmin = 100, xmax = 280, ymin = -40, ymax = 60) |>
      st_shift_longitude()
    
  } else {
    
    world <- ne_countries(scale = 10,
                          country = c("United States of America","Canada","Mexico"),
                          returnclass = "sf")
    
  }
  
  
  
  # Create 'nice' names for plot titles
  plot_title <- str_replace_all(string = savename, 
                                pattern = "((?<=[a-z])[A-Z]|[A-Z](?=[a-z]))",
                                replacement = " \\1") |> 
    gsub(pattern = "albacoretuna", replacement = "Albacore tuna") |> 
    gsub(pattern = "^pacific\\ ", replacement = "") |> 
    str_to_sentence()
  
  
  # Define map extent by tool
  spat_ext <- switch(tool,
                     "TopPredatorWatch" = c(xmin = 180, xmax = 260, ymin = 10, ymax = 62),
                     
                     "ROMS" = c(xmin = -134, xmax = -115.5, ymin = 30, ymax = 48),
                     
                     stop("Tool must be one of either 'TopPredatorWatch' or 'ROMS'."))
  
  
  # Create map object
  plot_sp <- ggplot() +
    geom_raster(data = pred.df, aes(x = x, y = y, fill = lyr1)) +
    scale_fill_gradientn("Habitat suitability", colours = pals::parula(100), na.value = "black") +
    geom_sf(data = world, color = "black", fill = "grey") +
    theme_classic() +
    labs(x = NULL, y = NULL) +
    coord_sf(xlim = spat_ext[1:2],
             ylim = spat_ext[3:4],
             expand = FALSE) +
    ggtitle(glue("{plot_title} {plot_date}")) +
    theme(legend.position = "bottom")
  
  
  # Export map
  switch(tool,
         "TopPredatorWatch" = ggsave(filename = glue("{pred_img_dir}/{savename}_{get_date}.png"),
                                     plot = plot_sp, width = 32, height = 22, units = "cm", dpi = 400),
         
         "ROMS" = ggsave(filename = glue("{pred_img_dir}/{savename}_{get_date}.png"),
                         plot = plot_sp, width = 4, height = 6, units = "in", dpi = 400),
         
         stop("Tool must be one of either 'TopPredatorWatch' or 'ROMS'."))
  
  
}
