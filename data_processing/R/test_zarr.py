
### Test reading Zarr from GCS bucket ###

import xarray as xr
# import zarr
# import gcsfs

# Define where to store Zarr file in bucket (and here, I'm telling it the new "zarr_cmems" folder to create and write all subfolders)
zarr_path = "gs://esd-climate-ecosystems-dev/zarr_cmems_v2"

# Now try reading this Zarr file stored in the bucket
ds_cloud = xr.open_zarr(zarr_path, 
                        consolidated=True,
                        storage_options={"token": "google_default"})
                        # storage_options={"token": "gcs_key.json"})  # W/ current permissions, requires creds
print(ds_cloud)
