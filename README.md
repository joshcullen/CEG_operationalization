# Operationalization of tools for the NOAA SWFSC Climate & Ecosystems Group

This repository serves as a centralized location for running scheduled jobs that provide input for a variety of operational tools. Specifically, it contains all code necessary to download environmental data from different sources (i.e., ROMS, ERDDAP, CMEMS) on a scheduled basis, make model predictions for relevant marine species, and generate products (e.g., rasters, images). 

Based on need, this repo may change to account for additional data sources, models, and species of interest. In its current form, below is a directory tree to show how this repo will be structured:

```bash

├── data_acquisition
│   ├── R
│   └── netcdfs
│       ├── cmems_ncdfs
│       ├── erddap_ncdfs
│       └── roms_ncdfs
├── model_prediction
│   ├── blue_whale
│   ├── humpback_whale
│   └── leatherback
│       ├── model_cmems
│       │   ├── R
│       │   ├── img
│       │   └── rasters
│       └── model_roms
│           ├── R
│           ├── img
│           └── rasters

```

