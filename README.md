# nys_psy

This repo holds the translation of the [NYgrid](https://github.com/AndersonEnergyLab-Cornell/NYgrid) model developed by the [Anderson Energy Lab](https://andersonenergylab-cornell.github.io/) at Cornell University to the Sienna Ecosystem. In addition to the baseline model developed based on the 2019 data, this repo also contains virtual wind and solar sites modeled for the New York's Climate Leadership & Community Protection Act for 2040. 

The 2040 version of the model has a unified correlated renewable and load profiles for 22 years. The methodology to generate these data is introduced in ["Heterogeneous Vulnerability of Zero-Carbon Power Grids under Climate-Technological Changes"](https://arxiv.org/abs/2307.15079) and the scripts to genreate these data and be found in the [ny-clcpa2050](https://github.com/AndersonEnergyLab-Cornell/ny-clcpa2050) repo.

# This Branch

This branch has the fuel costs modeled as time-series inputs. Using PSI v0.29.0, the system can be solved with time-series thermal costs. This branch is an augment of the `main` branch that don't contain the changes expected for the 2040 system. 

# Improvements
1. Start-up and no load costs and be modeled in the Sienna Ecosystem and enable a full unit commitment dispach.  (TODO)
2. Min up and min down time can be modeled 
3. Pumped Hydro has a more sophiscated model bus is lacking time-series data. 
4. Smaller hydro plant can have a time-series input to reflect seasonal variance

# Limitations

1. Nuclear had time varying upper bound based on maintanace schedule which is not modeled in this translation. 
(All these limitations are subject to change as Sienna expands its functionalities. )