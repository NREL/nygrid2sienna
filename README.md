# nys_psy

This repo holds the translation of the [NYgrid](https://github.com/AndersonEnergyLab-Cornell/NYgrid) model developed by the [Anderson Energy Lab](https://andersonenergylab-cornell.github.io/) at Cornell University to the Sienna Ecosystem. In addition to the baseline model developed based on the 2019 data, this repo also contains virtual wind and solar sites modeled for the New York's Climate Leadership & Community Protection Act for 2030 and 2050. 

The 2040 version of the model has a unified correlated renewable and load profiles for 22 years. The methodology to generate these data is introduced in ["Heterogeneous Vulnerability of Zero-Carbon Power Grids under Climate-Technological Changes"](https://arxiv.org/abs/2307.15079) and the scripts to genreate these data and be found in the [ny-clcpa2050](https://github.com/AndersonEnergyLab-Cornell/ny-clcpa2050) repo.

# This Branch

This branch holds the model of the 2040 zero-emission nys system. Additional/Change of components modeled compared to the baseline 2019 system are:
1. Land based and off-shore wind, modeled with formulation `RenewableFullDispatch`
2. Utility level solar, modeled with formulation `RenewableFullDispatch`
3. Behind-the-meter solar, modeled with formulation `FixedOutput`, which means the renewable output follows exactly as the time-series profile.
4. Storage modeled by formulation`StorageDispatchWithReserves`
5. Baseload is extrapolated by ANN for 22 years. (see paper above for modeling details)
6. Electrified building load from residential and commercial sectors modeled from Resstock and Comstock 
7. EV load modeled from EV-Pro-Lite. 
8. Two HVDC lines that will be online by 2027. 
9. Modifications on Interface Flow limits
10. Retirement of 3 nuclear plants. 



# Improvements
1. Start-up and no load costs can be modeled in the Sienna Ecosystem and enable a full unit commitment dispach.  (TODO)
2. Min up and min down time can be modeled 
3. Pumped Hydro has a more sophiscated model but islacking time-series data now 
4. Smaller hydro plant can potentially have a time-series input to reflect seasonal variance

# Limitations
1. Thermal units cost is not a time-series representation based on the weekly fuel price drawn from NYISO's report anymore (the `2019_timeseries_fuelcost` fixes this with the newest PSI, but the newest PSI is not comparable with HydroSimulation yet. )
2. The time-series zonal LBMP was used to on the neighboring region node as an approxy for generator costs, which cannot be effectively modeled now. (the `2019_timeseries_fuelcost` fixes this with the newest PSI, but the newest PSI is not comparable with HydroSimulation yet. )
3. Nuclear had time varying upper bound based on maintanace schedule which is not modeled in this translation. 
(All these limitations are subject to change as Sienna expands its functionalities. )