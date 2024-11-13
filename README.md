# Operationalization of tools for the NOAA SWFSC Climate & Ecosystems Group

This repository serves as a centralized location for running scheduled jobs that provide input for a variety of operational tools. Specifically, it contains all code necessary to download environmental data from different sources (i.e., ROMS, ERDDAP, CMEMS) on a scheduled basis, make model predictions for relevant marine species, and generate products (e.g., rasters, images).

Here is an example prediction from Top Predator Watch:
![](https://github.com/joshcullen/CEG_operationalization/blob/main/model_prediction/TopPredatorWatch/img/leatherbackTurtle_2024-11-08.png?raw=true)

And here is an example prediction from the ROMS tool:
![](https://github.com/joshcullen/CEG_operationalization/blob/main/model_prediction/ROMS/img/leatherbackTurtle_2024-11-08.png?raw=true)

Based on need, this repo may change to account for additional data sources, models, and species of interest. In its current form, below is a directory tree to show how this repo will be structured:

```bash

├── data_acquisition
│   ├── R
│   │   ├── acquire_example.R
│   │   └── acquire_utils.R
│   └── netcdfs
│       ├── cmems_ncdfs
│       ├── erddap_ncdfs
│       └── roms_ncdfs
├── data_processing
│   ├── R
│   │   ├── process_example.R
│   │   └── process_utils.R
│   ├── ROMS
│   │   ├── rasters
│   │   └── static
│   └── TopPredatorWatch
│       ├── rasters
│       └── static
├── docs
│   └── model_metadata.csv
└── model_prediction
    ├── R
    │   ├── predict_example.R
    │   └── predict_utils.R
    ├── ROMS
    │   ├── img
    │   ├── rasters
    │   └── static
    │       └── lbst_noSSH.res1.tc3.lr01.single.rds
    └── TopPredatorWatch
        ├── img
        ├── rasters
        └── static
            └── species_bernoulli_03_22_21_step_lr0.01_tc3_bf0.6_tol1e-05_bernoulli_leatherbackTurtle_TOPP.rds

```

