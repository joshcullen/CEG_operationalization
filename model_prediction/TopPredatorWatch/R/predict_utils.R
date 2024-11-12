
#' Function for making predictions from BRT (and/or other) models
#' 
#' The code for generating model predictions is currently written in a format that is generalizable across multiple tools. Some additional steps may be needed based on how the models were fitted and/or if masking of environmental rasters is necessary.
#'
#' @param dyn_rast_dir File path from which to import dynamic raster layers.
#' @param static_rast_dir File path from which to import static raster layers.
#' @param savename The file name to save the derived raster.
#' @param get_date Date of interest in YYYY-MM-DD format.
#' @param bbox An `sf` POLYGON or MULTIPOLYGON layer for which to mask rasters.
#' @param mod Model object from which to make predictions. CURRENTLY FORMATTED FOR BRT MODELS ONLY , BUT EASY TO ADJUST.
#' @param pred_rast_dir 
#'
#' @return Generates and exports a predictive surface for each species of interest.
#' 
#' @export
predict_models = function(dyn_rast_dir, static_rast_dir, savename, get_date, bbox, mod, pred_rast_dir) {
  
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
  
  
  # Mask rasters by bbox
  rast_stack2 <- terra::mask(rast_stack, bbox)
  
  # Make prediction
  if (class(mod) == 'gbm') {  # Fit BRT model objects
    pred <- predict(object = rast_stack2, model = mod, n.trees = mod$gbm.call$best.trees,
                    type = "response", na.rm = FALSE)
  } else {
    stop("Need to update `predicts_models()` function to make predictions on models other than BRT.")
  }
  
  pred2 <- terra::mask(pred, bbox)
  
  
  # Export prediction raster
  writeRaster(pred2, glue("{pred_rast_dir}/pred_{get_date}_{savename}.tiff"), overwrite = TRUE)
  
}





# Function to make standard images of tuna maps
make_png <- function(pred_rast_dir, get_date, savename, pred_img_dir) {
  
  print(glue("Making png of {savename} prediction"))
  
  # Import prediction raster
  pred <- rast(glue("{pred_rast_dir}/pred_{get_date}_{savename}.tiff"))
  
  
  # Format date for map
  plot_date <- format(as_date(get_date), format = "%B %d %Y")
  
  pred.df <- as.data.frame(pred, xy = TRUE)
  
  # load spatial layer for country polygons
  world <- gisco_countries |> 
    filter(NAME_ENGL != "Antarctica") |> 
    st_shift_longitude() |>
    st_crop(xmin = 100, xmax = 280, ymin = -40, ymax = 60) |>
    st_shift_longitude()
  
  
  
  # Create 'nice' names for plot titles
  plot_title <- str_replace_all(string = savename, 
                                pattern = "((?<=[a-z])[A-Z]|[A-Z](?=[a-z]))",
                                replacement = " \\1") |> 
    gsub(pattern = "albacoretuna", replacement = "Albacore tuna") |> 
    gsub(pattern = "^pacific\\ ", replacement = "") |> 
    str_to_sentence()
  
  # Create map object
  plot_sp <- ggplot() +
    geom_raster(data = pred.df, aes(x = x, y = y, fill = lyr1)) +
    scale_fill_gradientn("Habitat suitability", colours = pals::parula(100), na.value = "black") +
    geom_sf(data = world, color = "black", fill = "grey") +
    theme_classic() +
    labs(x = NULL, y = NULL) +
    coord_sf(xlim = c(180, 260), ylim = c(10,62), expand = FALSE) +
    ggtitle(glue("{plot_title} {plot_date}")) +
    theme(legend.position = "bottom")
  
  
  # Export map
  ggsave(filename = glue("{pred_img_dir}/{savename}_{get_date}.png"),
         plot = plot_sp, width = 32, height = 22, units = "cm", dpi = 400)
  
}
