# NYgrid Model Translation to the Sienna Ecosystem  

This repository contains the translation of the [NYgrid](https://github.com/AndersonEnergyLab-Cornell/NYgrid) model, developed by the [Anderson Energy Lab](https://andersonenergylab-cornell.github.io/) at Cornell University, into the Sienna Ecosystem. In addition to the baseline model, which is based on 2019 data, this repository includes virtual wind and solar sites modeled to align with New York's Climate Leadership & Community Protection Act (CLCPA) targets for 2040.  

The 2040 version of the model features a unified, correlated dataset of renewable generation and load profiles spanning 22 years. The methodology used to generate these data is detailed in ["Heterogeneous Vulnerability of Zero-Carbon Power Grids under Climate-Technological Changes"](https://arxiv.org/abs/2307.15079), and the scripts for data generation are available in the [ny-clcpa2050](https://github.com/AndersonEnergyLab-Cornell/ny-clcpa2050) repository.  

> **Note:** While this test system is designed to simulate the power flow of the New York State transmission system, it does not represent the actual transmission network.


# Branch Info:

1. The `main` branch has the 2019 baseline system, which has been validated with the model in the [NYgrid](https://github.com/AndersonEnergyLab-Cornell/NYgrid) repo. The main draw back is that this branch doesn't have time-series thermal cost data. This branch is a good start point to make and test any additional improvements for the model. 
2. The `2019_timeseries_fuelcost` branch has the time-series fuel cost. By using the V0.29.0 verison of PSI, it duplicates the models in the [NYgrid](https://github.com/AndersonEnergyLab-Cornell/NYgrid) repo. 
3. The `clcpa2040` branch has the 2040 version of the model with all the renewables and electrified load for 22 years. 

# Potential Improvements from Sienna Ecosystem
1. Start-up and no load costs and be modeled in the Sienna Ecosystem and enable a full unit commitment dispach. (TODO)
2. Min up and min down time can be modeled. (Data required)
3. Pumped Hydro has a more sophiscated model but is lacking time-series data.
4. Smaller hydro plant can have a time-series input to reflect seasonal variance

# Limitations

1. Nuclear had time varying upper bound based on maintanace schedule which is not modeled in this translation. 
(All these limitations are subject to change as Sienna expands its functionalities. )


# Data Source:
1. Network Data: Original NPCC140 data is avaialble from https://github.com/CURENT/andes/tree/master/andes/cases/npcc.
2. The 2019 Baseline load, power flow, fuel mix, fuel cost and price data are available from NYISO OASIS: http://mis.nyiso.com/public
3. More details on Baseline model assumptions is available from [An Open Source Representation for the NYS Electric Grid to Support Power Grid and Market Transition Studies](https://ieeexplore.ieee.org/abstract/document/9866561).
4. The 2040 wind and solar profiles are created using the [Wind Integration National Dataset Toolkits](https://www.nrel.gov/grid/wind-toolkit.html) and the [Solar Integration National Dataset Toolkit](https://www.nrel.gov/grid/sind-toolkit.html) along with the [MERRA-2](https://gmao.gsfc.nasa.gov/reanalysis/merra-2/) reanalysis data. 
5. The electrification of buildings and EVs uses data from [ComStock](https://comstock.nrel.gov/), [ResStock](https://resstock.nrel.gov/) and [EVI-Pro Lite](https://afdc.energy.gov/evi-x-toolbox#/evi-pro-ports). 


# License
The repository was built from open source resources. The material in this repository were developed at the National Renewable Energy Laboratory under SWR-25-63. The materials in this repository are subject to the BSD-3-Clause License.

