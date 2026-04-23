
# Shiny app to explore CMEMS predictions and covariates by date

library(shiny)
library(bslib)
library(httr)
library(jsonlite)
library(dplyr)
library(stringr)
library(glue)
library(leaflet)
library(leafem)
library(terra)
library(cmocean)
library(reticulate)


###########################################################
### Set up venv and Python to read Zarr from GCS bucket ###
###########################################################

# Tell R to use this specific environment
# use_virtualenv("r-shiny-zarr", required = TRUE)

py_require(
  packages = c("xarray", "zarr", "gcsfs", "numpy", "certifi"),
  python_version = "3.12"
)

#Setup Python Environment
# Ensure xarray, zarr, and gcsfs (for Google storage) are installed
xr <- import("xarray")

# SSL fix for Linux/shinyapps.io
certifi <- import("certifi")
Sys.setenv(SSL_CERT_FILE = certifi$where())
Sys.setenv(REQUESTS_CA_BUNDLE = certifi$where())

# Define path for Zarr file
zarr_path <- "gs://esd-climate-ecosystems-dev/zarr_cmems_v2"


# Path to your uploaded Service Account Key
# IMPORTANT: Ensure this file is in your project folder when you click 'Publish'
json_str <- Sys.getenv("GCS_AUTH_JSON")
temp_key_file <- tempfile(fileext = ".json")
writeLines(json_str, temp_key_file)
key_file <- temp_key_file

# Clean up the temporary file when the Shiny session ends
onStop(function() {
  if (file.exists(temp_key_file)) {
    file.remove(temp_key_file)
  }
})


# Open the dataset using creds (since bucket is currently private)
ds_cloud <- xr$open_zarr(
  zarr_path, 
  consolidated = TRUE,
  # storage_options = list(token = "/Users/joshcullen/.config/gcloud/application_default_credentials.json")
  storage_options = list(token = key_file)
)


# Define list of covars to viz
# covar_list <- ds_cloud$variables$mapping |> 
#   names() |> 
#   str_subset(pattern = "crs|ugosa|vgosa|longitude|latitude|time", negate = TRUE)

covar_dict <- data.frame(raw_name = c("analysed_sst","eke","CHL","mlotst","nppv","sst_sd","o2","sla"),
                         new_name = c("sst","eke","log_chla","mld","PPupper200m","sst_sd","o2_200m","sla"))
  
  

read_zarr <- function(data, get_date, covar) {
  
  # Access Python object and use xarray methods directly
  r_py <- data[[covar]]$sel(time = get_date)
  
  # Convert to R terra object
  # We extract the values as a matrix/array and the spatial metadata
  values <- r_py$data
  lons <- r_py$longitude$values
  lats <- r_py$latitude$values
  crs_wkt <- ds_cloud$crs$variable$attrs$crs_wkt
  
  # Create the SpatRaster
  r_terra <- rast(
    values,
    crs = crs_wkt,
    extent = ext(min(lons), max(lons), min(lats), max(lats))
  )
  
  
  return(r_terra)
}

#############################
### Check data on GH repo ###
#############################

# GitHub API URLs
base_api <- "https://api.github.com/repos/joshcullen/CEG_operationalization/contents"

# Folders
pred_folder <- "model_prediction/TopPredatorWatch/rasters"
# env_folder <- "data_processing/TopPredatorWatch/rasters"

# Function to get file listing from GitHub folder
get_file_dates <- function(folder, pattern, strip_pattern, strip = TRUE) {
  res <- GET(glue("{base_api}/{folder}"))
  stop_for_status(res)
  files <- content(res, as = "parsed")
  
  tibble(
    name = sapply(files, `[[`, "name"),
    url = sapply(files, `[[`, "download_url")
  ) |>
    filter(str_detect(name, pattern)) |>
    mutate(date = str_extract(name, "\\d{4}-\\d{2}-\\d{2}")) |>
    filter(!is.na(date)) |>
    mutate(
      layer = if (strip) str_remove(name, strip_pattern) else name,
      layer = str_replace(layer, "\\.tiff$", "")
    )
}

# Get prediction rasters
pred_rasters <- get_file_dates(folder = pred_folder,
                               pattern = "^pred_\\d{4}-\\d{2}-\\d{2}_leatherbackTurtle\\.tiff$",
                               strip_pattern = "_\\d{4}-\\d{2}-\\d{2}_leatherbackTurtle\\.tiff$",
                               strip = TRUE)

# Get environmental rasters
# env_rasters <- get_file_dates(folder = env_folder,
#                               pattern = "\\.tiff$",
#                               strip_pattern = "_\\d{4}-\\d{2}-\\d{2}",
#                               strip = TRUE) |> 
#   filter(!str_detect(name, "day|ugosa|vgosa"))  #remove unneeded variables

# Combine both
# all_rasters <- bind_rows(pred_rasters, env_rasters)

# Create a dropdown of available dates (those that appear in all layers)
valid_dates <- #intersect(pred_rasters$date, env_rasters$date) |> 
  pred_rasters$date |> 
  sort(decreasing = TRUE) |> 
  as.character()


# Define list of palette colors from {cmocean} to viz covars
# covar_pal_df <- data.frame(covar = unique(env_rasters$layer),
#                            pals = c("algae","tempo","algae","dense","matter","delta","thermal","amp"))
covar_pal_df <- data.frame(covar = covar_dict$new_name,
                           pals = c("thermal","tempo","algae","dense","algae","amp","matter","delta"))




#################
### Define UI ###
#################

ui <- page_fluid(
  # title = "My app",
  # sidebar = sidebar(
  #   title = "Inputs"
  # ),
  # tags$head(
  #   tags$style(type="text/css", "label.control-label, .selectize-control.single{ display: table-cell; text-align: center; vertical-align: middle; } .form-group { display: table-row;}")
  # ),
  layout_column_wrap(
    width = "200px",
    fixed_width = TRUE,
    heights_equal = "row",
    selectInput(inputId = "date",
                "Select date: ",
                choices = "Loading dates...",
                # selected = valid_dates[1],
                multiple = FALSE,
                width = "150px"),
    
    selectInput(inputId = "covar",
                "Select variable: ",
                # choices = unique(env_rasters$layer),
                # selected = unique(env_rasters$layer)[1],
                choices = covar_dict$new_name,
                selected = covar_dict$new_name[1],
                multiple = FALSE,
                width = "150px")
  ),
  
  # Add navset tab
  navset_card_tab(
    nav_panel(title = "Model Prediction",
              card(full_screen = TRUE,
                   leafletOutput("pred_map")
              )
    ),
    
    nav_panel(title = "Environ. Predictors",
              card(full_screen = TRUE,
                   leafletOutput("covar_map")
              )
    )
  )
)


#####################
### Define server ###
#####################

server <- function(input, output, session) {
  
  #Update dropdown w/ dates from GH files
  updateSelectInput(session, "date", choices = valid_dates, selected = valid_dates[1])
  
  
  ## Filter data based on select input
  pred_rast <- reactive({
    #Stop execution if date is missing or is the placeholder string
    req(input$date)
    req(input$date != "Loading dates...")
    
    pred_rasters |> 
      filter(date == input$date) |> 
      pull(url) |> 
      rast() |> 
      project('EPSG:3857')  # Reproject so properly mapped by leaflet
  })
  
  # covar_rast <- reactive({
  #   env_rasters |> 
  #     filter(date == input$date,
  #            layer == input$covar) |> 
  #     pull(url) |> 
  #     rast() |> 
  #     # project('EPSG:3857') |>  # Reproject so properly mapped by leaflet
  #     crop(pred_rast())  #crop to match same extent as prediction
  # })
  covar_rast <- reactive({
    #Stop execution if date is missing or is the placeholder string
    req(input$date)
    req(input$date != "Loading dates...")
    
    # Need to project the prediction raster back to unprojected 
    # to match the incoming Zarr extent for cropping
    base_pred <- pred_rasters |> 
      filter(date == input$date) |> 
      pull(url) |> 
      rast()
    
    ds_cloud |> 
      read_zarr(get_date = input$date,
                covar = covar_dict[covar_dict$new_name == input$covar, "raw_name"]) |> 
      crop(base_pred) |>  #crop to match same extent as prediction
      project('EPSG:3857')  # Reproject so properly mapped by leaflet
  })
  
   
  
  ## Map prediction layer
  
  # Create basemap for prediction
  output$pred_map <- renderLeaflet({
    leaflet() |> 
      setView(lng = -130, lat = 30, zoom = 3) |> 
      addProviderTiles(provider = providers$CartoDB.DarkMatter, group = "CartoDB",
                       options = providerTileOptions(zIndex = -10)) |> 
      addProviderTiles(provider = providers$Esri.WorldImagery, group = "Satellite",
                       options = providerTileOptions(zIndex = -10)) |> 
      addProviderTiles(provider = providers$Esri.OceanBasemap, group = "Bathymetry",
                       options = providerTileOptions(zIndex = -10)) |> 
      addLayersControl(position = "topright",
                       baseGroups = c("CartoDB","Satellite","Bathymetry"),
                       overlayGroups = "HSI",
                       options = layersControlOptions(collapsed = TRUE, autoZIndex = FALSE))
    })
  
  # Add reactive layer to map
  observe({
    # STOP execution here if pred_rast() is not ready
    req(pred_rast())
    
    # Define color palette for raster layers
    pal <- colorNumeric("inferno", domain = values(pred_rast()), na.color = "transparent")
    
    leafletProxy("pred_map") |> 
      clearControls() |> 
      clearImages() |>
      addRasterImage(pred_rast(), colors = pal, opacity = 0.8, group = "HSI", layerId = "HSI") |> 
      addImageQuery(pred_rast(), layerId = "HSI") |>  #add raster  query
      addLegend(title = "Habitat Suitability", position = "bottomright", pal = pal, values = values(pred_rast()))
  })
  
  
  ## Map covar layers
  
  # Create basemap for covar layers
  output$covar_map <- renderLeaflet({
    leaflet() |>
      setView(lng = -130, lat = 30, zoom = 3) |>
      addProviderTiles(provider = providers$CartoDB.DarkMatter, group = "CartoDB",
                       options = providerTileOptions(zIndex = -10)) |>
      addProviderTiles(provider = providers$Esri.WorldImagery, group = "Satellite",
                       options = providerTileOptions(zIndex = -10)) |>
      addProviderTiles(provider = providers$Esri.OceanBasemap, group = "Bathymetry",
                       options = providerTileOptions(zIndex = -10)) |>
      addLayersControl(position = "topright",
                       baseGroups = c("CartoDB","Satellite","Bathymetry"),
                       overlayGroups = c("covar"),
                       options = layersControlOptions(collapsed = TRUE, autoZIndex = FALSE))
  })

  
  # Add reactive layer to map
  outputOptions(output, "covar_map", suspendWhenHidden = FALSE)  #need for displaying points for map on load
  
  observe({
    req(covar_rast())
    
    # Select palette to use
    covar_pal_name <- covar_pal_df |> 
      filter(covar == input$covar) |> 
      pull(pals)
    
    # Define palette
    covar_pal <- colorNumeric(cmocean(covar_pal_name)(256), domain = values(covar_rast()), na.color = "transparent")
    
    leafletProxy("covar_map") |> 
      clearControls() |> 
      clearImages() |>
      addRasterImage(x = covar_rast(), colors = covar_pal, opacity = 1, group = "covar") |>
      addImageQuery(covar_rast(), group = "covar", layerId = "covar") |>  #add raster  query
      addLegend(title = paste(input$covar), position = "bottomright", pal = covar_pal,
                values = values(covar_rast()), layerId = "covar", group = "covar") 
  })
  
}


###############
### Run app ###
###############

shinyApp(ui, server)
