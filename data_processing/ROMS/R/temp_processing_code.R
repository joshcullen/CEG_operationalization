### sample code to process ROMS data for lbst model

## 1. raw variables that only need to be resampled to data_processing/ROMS/static/template.grd:
# curl
# ild
# ssh
# sst
# su
# sv
# sustr
# svstr
# bv
## resampling code: r_resampled <- resample(r_raw, template, method="bilinear") 

## 2. derived variables - SDs (these variables are directly calculated from the resampled layers above)
# ssh_sd: rasSD=focal(ras,w=matrix(1,nrow=7,ncol = 7),fun=sd,na.rm=T,pad=T) 
# sst_sd: rasSD=focal(ras,w=matrix(1,nrow=7,ncol = 7),fun=sd,na.rm=T,pad=T)

## 3. EKE (directly calculated from resampled su and sv, above)
# su=raster(paste0(dailyDir,"/su.grd"))
# sv=raster(paste0(dailyDir,"/sv.grd"))
# eke=(su^2+sv^2)/2%>%log()

## 4. other
# lunillium (amount of moonlight hitting ocean surface; from the lunar package):
# value <- lunar.illumination(as.Date(get_date))
# lunar_ras=raster(paste0(staticDir,"/template.grd"))
# values(lunar_ras)=value

# z and zsd (bathy and bathy standard deviation)
# data_processing/ROMS/static/z_.1.grd --> gets rename to z.grd
# data_processing/ROMS/static/zsd_.3.grd --> gets rename to z_sd.grd

