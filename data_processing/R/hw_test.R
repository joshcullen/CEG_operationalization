## test resample 
library(terra)
template=rast("data_processing/TopPredatorWatch/static/template.grd")
file="data_acquisition/netcdfs/cmems_ncdfs/cmems_obs-sl_glo_phy-ssh_nrt_allsat-l4-duacs-0.25deg_P1D_vgosa_2024-11-14.nc"
ras=rast(file)
resam=terra::resample(ras,template)
terra::writeRaster(resam,"data_processing/TopPredatorWatch/rasters/test.tiff")