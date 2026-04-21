

### Create multi-variable Zarr for CEG_operationalization and upload to GCS bucket ###

import xarray as xr
# import zarr
# import gcsfs
import datetime as dt
# import glob


# Load in netCDFs
get_date = (dt.date.today() - dt.timedelta(days=1)).strftime("%Y-%m-%d")  #yesterday

file_path = f"data_processing/TopPredatorWatch/rasters/*{get_date}.nc"
# all_files = glob.glob(file_path)
# exclude_list = ["ugosa", "vgosa"]
# filtered_files = [f for f in all_files if not any(x in f for x in exclude_list)]

ds = xr.open_mfdataset(file_path)

# View size of dataset
print(f"Size in TB: {ds.nbytes / 1e12:.2f} TB")
ds.sizes
print(ds)




# Define where to store Zarr file in bucket (and here, I'm telling it the new "zarr_cmems" folder to create and write all subfolders)
zarr_path = "gs://esd-climate-ecosystems-dev/zarr_cmems"

## Need to make sure that an application_default_credentials.json is stored in the "~/.config/gcloud/" path
## If not, need to run `gcloud auth application-default login` assuming gcloud SDK already installed

# Ensure that all variables include a time dim (by matching dims from sst)
# ds = ds.broadcast_like(ds[['analysed_sst']])
# ds['crs'] = ds['crs'].isel(time=0, drop=True)
ds['crs'] = ds['crs'].expand_dims('time')  #needs to match format in bucket

# Write to cloud bucket
#%%time  #not working right now (for some reason)
ds.to_zarr(
    zarr_path,
    mode="a-",  # append only specified dims
    append_dim="time",
    consolidated=False,
    storage_options={"token": "google_default"})
#took 1.5 min to run (for 41 MB dataset)



# Now try reading this Zarr file stored in the bucket
# ds_cloud = xr.open_zarr(zarr_path, 
#                         consolidated=False,
#                         storage_options={"token": "google_default"})  # W/ current permissions, requires creds
# print(ds_cloud)
# ds_cloud.chunks

# # Subset Zarr data from cloud and plot
# ds_cloud['analysed_sst'].sel(
#   latitude=slice(50, 20), 
#   longitude=slice(220, 260)
#   ).isel(time=-1).plot(aspect="equal", size=7)

# ds_cloud.time.values
