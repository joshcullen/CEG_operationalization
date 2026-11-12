
### Create multi-variable Zarr for CEG_operationalization and upload to GCS bucket ###

import xarray as xr
import datetime as dt
import glob
import os
import sys
import re

# 1. Define required variables, Zarr path, and local directory
required_vars = ['CHL','nppv','eke','mlotst','o2','sla','analysed_sst','sst_sd','ugosa','vgosa']
zarr_path = "gs://esd-climate-ecosystems-dev/zarr_cmems_v2"
raster_dir = "data_processing/TopPredatorWatch/rasters"

# 2. Get existing dates from the Zarr store to prevent duplicates
try:
    ds_cloud = xr.open_zarr(
        zarr_path, 
        consolidated=True, 
        storage_options={"token": "google_default"}
    )
    # Extract existing dates as a set of 'YYYY-MM-DD' strings
    existing_dates = set(ds_cloud.time.dt.strftime('%Y-%m-%d').values)
    print(f"Found {len(existing_dates)} dates already in Zarr store.")
except Exception as e:
    print("Could not load existing Zarr store (it may be empty/new). Proceeding with empty set.")
    existing_dates = set()

# 3. Find all unique dates present in the local rasters directory
all_files = glob.glob(f"{raster_dir}/*.nc")
date_pattern = re.compile(r'\d{4}-\d{2}-\d{2}')
local_dates = set()

for f in all_files:
    match = date_pattern.search(f)
    if match:
        local_dates.add(match.group())

# 4. Isolate NEW dates and sort them chronologically (Critical for Zarr appending)
dates_to_process = sorted(list(local_dates - existing_dates))

if not dates_to_process:
    print("No new/unappended dates found in the local directory. Exiting cleanly.")
    sys.exit(0)

print(f"Found {len(dates_to_process)} new date(s) to evaluate: {dates_to_process}")

# 5. Process and append each new date sequentially
for process_date in dates_to_process:
    print(f"\n--- Evaluating data for {process_date} ---")
    
    file_path = f"{raster_dir}/*{process_date}.nc"
    
    try:
        ds = xr.open_mfdataset(file_path)
    except Exception as e:
        print(f"Error opening datasets for {process_date}: {e}")
        continue
    
    # Validate that all required layers are present for this specific date
    missing_vars = [var for var in required_vars if var not in ds.data_vars]
    
    if missing_vars:
        print(f"ZARR UPDATE SKIPPED FOR {process_date}: Missing required variables: {missing_vars}.")
        # Continue to the next date in the loop instead of failing the script entirely
        continue 
    
    print(f"All required variables present for {process_date}. Appending to Zarr store.")
    
    # Ensure that all variables include a time dim (by matching dims from sst)
    ds['crs'] = ds['crs'].expand_dims('time')
    
    # Write to cloud bucket
    ds.to_zarr(
        zarr_path,
        mode="a-",  # append only specified dims
        append_dim="time",
        consolidated=True,
        storage_options={"token": "google_default"}
    )
    
    print(f"Successfully appended {process_date} to Zarr store.")

print("\nZarr update routine completed.")
