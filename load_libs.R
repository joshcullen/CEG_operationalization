## load libs

library(glue)
library(terra)
library(tidyverse)  ## 2.0.0
library(sf)
library(RCurl)
library(ncdf4) ## needed to interact with ROMS THREDDS server - rast() doesn't work
