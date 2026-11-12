

### Create multi-variable Zarr for CEG_operationalization and upload to GCS bucket ###

import xarray as xr
# import zarr
# import gcsfs
import datetime as dt
# import glob
import os
import sys


# Load in netCDFs
get_date = (dt.date.today() - dt.timedelta(days=1)).strftime("%Y-%m-%d")  #yesterday

file_path = f"data_processing/TopPredatorWatch/rasters/*{get_date}.nc"
# all_files = glob.glob(file_path)
# exclude_list = ["ugosa", "vgosa"]
# filtered_files = [f for f in all_files if not any(x in f for x in exclude_list)]

ds = xr.open_mfdataset(file_path)

# Validate that all required layers are present
required_vars = ['CHL','nppv','eke','mlotst','o2','sla','analysed_sst','sst_sd','ugosa','vgosa'] # Update this string to match your exact NetCDF variable name (e.g., 'chl' or 'CHL')
missing_vars = [var for var in required_vars if var not in ds.data_vars]

gh_env = os.getenv('GITHUB_ENV')

if missing_vars:
    print(f"ZARR UPDATE SKIPPED: Missing required variables: {missing_vars}.")
    # Exit with status 0 so the job doesn't fail, but skip the to_zarr execution
    sys.exit(0) 

print("All required variables present. Updating Zarr store.")

print(f"Size in TB: {ds.nbytes / 1e12:.2f} TB")
print(ds)




# Define where to store Zarr file in bucket (and here, I'm telling it the new "zarr_cmems_v2" folder to create and write all subfolders)
zarr_path = "gs://esd-climate-ecosystems-dev/zarr_cmems_v2"

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
    consolidated=True,
    storage_options={"token": "google_default"})
#took 1.5 min to run (for 41 MB dataset)



# Now try reading this Zarr file stored in the bucket
# ds_cloud = xr.open_zarr(zarr_path, 
#                         consolidated=True,
#                         storage_options={"token": "google_default"})  # W/ current permissions, requires creds
# print(ds_cloud)
# ds_cloud.chunks

# # Subset Zarr data from cloud and plot
# ds_cloud['analysed_sst'].sel(
#   latitude=slice(50, 20), 
#   longitude=slice(220, 260)
#   ).isel(time=-1).plot(aspect="equal", size=7)

# ds_cloud.time.values
