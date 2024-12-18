# nys_psy

This repo holds the translation of the [NYgrid](https://github.com/AndersonEnergyLab-Cornell/NYgrid) model developed by the [Anderson Energy Lab](https://andersonenergylab-cornell.github.io/) at Cornell University to the Sienna Ecosystem. In addition to the baseline model developed based on the 2019 data, this repo also contains virtual wind and solar sites modeled for the New York's Climate Leadership & Community Protection Act for 2040. 

The 2040 version of the model has a unified correlated renewable and load profiles for 22 years. The methodology to generate these data is introduced in ["Heterogeneous Vulnerability of Zero-Carbon Power Grids under Climate-Technological Changes"](https://arxiv.org/abs/2307.15079) and the scripts to genreate these data and be found in the [ny-clcpa2050](https://github.com/AndersonEnergyLab-Cornell/ny-clcpa2050) repo.

# Potential Improvements from Sienna Ecosystem
1. Start-up and no load costs and be modeled in the Sienna Ecosystem and enable a full unit commitment dispach.
2. Min up and min down time can be modeled 
3. Pumped Hydro has a more sophiscated model 
4. Smaller hydro plant can have a time-series input to reflect seasonal variance

# Limitations
1. Thermal units cost is not a time-series representation based on the weekly fuel price drawn from NYISO's report anymore 
2. The time-series zonal LBMP was used to on the neighboring region node as an approxy for generator costs, which cannot be effectively modeled now. 
3. Nuclear had time varying upper bound based on maintanace schedule which is not modeled in this translation. 
(All these limitations are subject to change as Sienna expands its functionalities. )
(12/18/2024 Updates: the time-series thermal variable cost is now supported by PowerSimulations v0.29.0 and the variable cost is implemented in the `2019_timeseries_fuelcost` branch)