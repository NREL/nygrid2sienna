using CSV
using DataFrames
using Dates
using TimeSeries
using InfrastructureSystems
using PowerSystems
const PSY = PowerSystems
const IS = InfrastructureSystems

include("parsing_utils.jl")

base_power = 100
load_year = 2019
sys = PSY.System(base_power)
set_units_base_system!(sys, PSY.UnitSystem.NATURAL_UNITS)

df_bus = CSV.read("config/bus_config.csv", DataFrame)

##########################
##### ADD LOAD ZONE ######
##########################
zone_list = unique(df_bus[!, "zone"])
for zone in zone_list
    z = PSY.Area(zone, 0.0, 0.0)
    PSY.add_component!(sys, z)
end

##########################
##### ADD BUS ######
##########################
for (bus_id, bus) in enumerate(eachrow(df_bus))
    number = bus.busIdx
    name = bus.name * "_" * string(bus.Vn)
    bustype = bus.busType
    angle = bus.a0
    magnitude = bus.v0
    voltage_limits = (min=bus.vmin, max=bus.vmax)
    base_voltage = bus.Vn
    area = get_component(PSY.Area, sys, bus.zone)
    _build_bus(sys, number, name, bustype, angle, magnitude, voltage_limits, base_voltage, area)
end

##########################
##### ADD Transmission ###
##########################
df_branch = CSV.read("config/branch_config_2040.csv", DataFrame)
br_name_list = Set()
for (br_id, br) in enumerate(eachrow(df_branch))
    from_id = br.from
    to_id = br.to
    from_bus = first(get_components(x -> PSY.get_number(x) == from_id, ACBus, sys))
    to_bus = first(get_components(x -> PSY.get_number(x) == to_id, ACBus, sys))
    v1 = PSY.get_base_voltage(from_bus)
    v2 = PSY.get_base_voltage(to_bus)
    name = string(from_id) * "-" * string(to_id)
    if name in br_name_list
        name = name * "~2"
    end
    push!(br_name_list, name)
    r = br.r
    x = br.x
    b = br.b
    if br.rating_A != 0.0
        rating = br.rating_A
    else
        rating = 99999.0
    end
    if v1 == v2
        _build_lines(sys; frombus=from_bus, tobus=to_bus, name=name, r=r, x=x, b=b, rating=rating)
    else
        _build_transformers(sys; frombus=from_bus, tobus=to_bus, name=name, r=r, x=x, b=b, rating=rating)
    end
end

##########################
##### ADD DCline #########
##########################

df_hvdc = CSV.read("config/hvdc_config.csv", DataFrame)
for (hvdc_id, hvdc) in enumerate(eachrow(df_hvdc))
    name = hvdc.name
    from_id = hvdc.from_bus
    to_id = hvdc.to_bus
    from_bus = first(get_components(x -> PSY.get_number(x) == from_id, ACBus, sys))
    to_bus = first(get_components(x -> PSY.get_number(x) == to_id, ACBus, sys))
    rating = hvdc.Pmax
    _build_hvdc(sys; frombus=from_bus, tobus=to_bus, name=name, r=0.0, x=0.0, b=0.0, rating=rating)
end

##########################
### ADD InterfaceLimits ##
##########################
df_iflim = CSV.read("config/interfaceflow_limits_2030.csv", DataFrame)
df_ifmap = CSV.read("config/interfaceflow_mapping_2030.csv", DataFrame)
for idx = 1:nrow(df_iflim)
    name = "IF_" * string(idx)
    rating_lb = df_iflim[df_iflim.index.==Int(idx), :rating_lb][1]
    rating_ub = df_iflim[df_iflim.index.==Int(idx), :rating_ub][1]
    setoflines = df_ifmap[df_ifmap.index.==Int(idx), :mapping]
    signofline = float(df_ifmap[df_ifmap.index.==Int(idx), :sign])
    ifdict = Dict(zip(string.(setoflines), signofline))
    _build_interface_flow(sys; name, rating_lb, rating_ub, ifdict)
end

##########################
### ADD Generators #######
##########################

pm_mapping = Dict(
    "Combustion Turbine" => PrimeMovers.CT,
    "Combined Cycle" => PrimeMovers.CC,
    "Internal Combustion" => PrimeMovers.IC,
    "Steam Turbine" => PrimeMovers.ST,
    "Jet Engine" => PrimeMovers.GT,
)

fuel_mapping = Dict(
    "Kerosene" => ThermalFuels.DISTILLATE_FUEL_OIL,
    "Natural Gas" => ThermalFuels.NATURAL_GAS,
    "Fuel Oil 2" => ThermalFuels.DISTILLATE_FUEL_OIL,
    "Coal" => ThermalFuels.COAL,
    "Fuel Oil 6" => ThermalFuels.RESIDUAL_FUEL_OIL,
)
#### Add Thermal #########
df_thermal = CSV.read("config/thermal_config.csv", DataFrame)
fuel_cost = CSV.read("Data/fuelPriceWeekly_2019.csv", DataFrame)
for (th_id, th) in enumerate(eachrow(df_thermal))
    name = th.Name
    bus = first(get_components(x -> PSY.get_number(x) == th.BusId, ACBus, sys))
    fuel = fuel_mapping[th.FuelType]
    pmin = th.Pmin
    pmax = th.Pmax
    # if pmin == 0.0
    #     pmin = 0.2 * pmax ## TODO: find better way to estimate pmin
    # end
    op_cost = _add_thermal_cost(th.HeatRateLM_1, th.HeatRateLM_0, th.Zone, th.FuelType, pmin, fuel_cost)
    ramp_rate = th.maxRamp10 / 10.0
    pm = pm_mapping[th.UnitType]
    generator = _add_thermal(sys, bus, name=name, fuel=fuel, cost=op_cost, pmin=pmin, pmax=pmax, ramp_rate=ramp_rate, pm=pm)
end

##  Add Nuclear ##############
df_nuclear = CSV.read("config/nuclear_config.csv", DataFrame)
nuclear_cf = CSV.read("Data/nuclearGenDaily_2019.csv", DataFrame)
for (th_id, th) in enumerate(eachrow(df_nuclear)) # TODO: nuclear maintainance not considered
    name = th.Name
    bus = first(get_components(x -> PSY.get_number(x) == th.BusId, ACBus, sys))
    fuel = ThermalFuels.NUCLEAR
    pmin = th.Pmin
    pmax = th.Pmax
    op_cost = ThermalGenerationCost(;
        variable=FuelCurve(; value_curve=LinearCurve(1.1), fuel_cost=1.0),
        fixed=0.0,
        start_up=0.0,
        shut_down=0.0,
    )
    ramp_rate = th.maxRamp10 / 10.0
    pm = PrimeMovers.ST
    generator = _add_nuclear(sys, bus, name=name, fuel=fuel, cost=op_cost, pmin=pmin, pmax=pmax, ramp_rate=ramp_rate, pm=pm)
end

##  Add Hydro ##############
df_hydro = CSV.read("config/hydro_config.csv", DataFrame)
for (hy_id, hy) in enumerate(eachrow(df_hydro))
    name = hy.Name
    bus = first(get_components(x -> PSY.get_number(x) == hy.BusId, ACBus, sys))
    pmin = hy.Pmin
    pmax = hy.Pmax
    op_cost = HydroGenerationCost(;
        variable=FuelCurve(; value_curve=LinearCurve(3.0), fuel_cost=1.0),
        fixed=0.0,
    )
    ramp_rate = hy.maxRamp10 / 10.0
    pm = PrimeMovers.HY
    timest = get_timestamp(load_year)
    hy_ts = ones(size(timest)) * pmax
    generator = _add_hydro(sys, bus, name=name, cost=op_cost, pmin=pmin, pmax=pmax, ramp_rate=ramp_rate, pm=pm, ts=hy_ts)
end

##  Add AggGen ###########
zonename_mapping = Dict(
    "NEISO" => "NPX",
    "PJM" => "PJM",
    "IESO" => "O H",
    "HQ" => "H Q",
)
df_agg = CSV.read("config/agggen_config.csv", DataFrame)
df_hourlylmp = CSV.read("Data/priceHourly_2019.csv", DataFrame)
for (th_id, th) in enumerate(eachrow(df_agg))
    name = th.Name
    bus = first(get_components(x -> PSY.get_number(x) == th.BusId, ACBus, sys))
    fuel = ThermalFuels.OTHER
    pmin = th.Pmin
    if name != "Hqimport"
        pmax = th.Pmax
    else
        pmax = th.Pmax
    end
    # if pmin == 0.0
    #     pmin = 0.2 * pmax ## TODO: find better way to estimate pmin
    # end
    filtered_df = filter(row -> row.ZoneName == zonename_mapping[th.Zone], df_hourlylmp)
    zonal_price = filtered_df[1, "LBMP"] ###TODO: this needs to be a time-series
    op_cost = ThermalGenerationCost(;
        variable=FuelCurve(; value_curve=LinearCurve(zonal_price), fuel_cost=1.0),
        fixed=0.0,
        start_up=0.0,
        shut_down=0.0,
    )
    ramp_rate = th.maxRampAgc
    pm = PrimeMovers.OT
    generator = _add_thermal(sys, bus, name=name, fuel=fuel, cost=op_cost, pmin=pmin, pmax=pmax, ramp_rate=ramp_rate, pm=pm)
end

##########################
### ADD Loads ############
##########################

###### Baseline Load ##########
baseline_load_profile = CSV.read("load_profile/Baseload/Baseload_" * string(load_year) * ".csv", DataFrame)
for busid in names(baseline_load_profile)
    bus = first(get_components(x -> PSY.get_number(x) == parse(Float64, busid), ACBus, sys))
    name = "Baseline_load_" * busid
    load_ts = baseline_load_profile[!, busid]
    _build_load(sys, bus, name, load_ts, load_year)
end

###### Comstock Load ##########
comstock_load_profile = CSV.read("load_profile/Comload/Comload_" * string(load_year) * ".csv", DataFrame)
for busid in names(comstock_load_profile)
    bus = first(get_components(x -> PSY.get_number(x) == parse(Float64, busid), ACBus, sys))
    name = "Comstock_load_" * busid
    load_ts = comstock_load_profile[!, busid]
    _build_load(sys, bus, name, load_ts, load_year)
end

###### Resstock Load ##########
resstock_load_profile = CSV.read("load_profile/Resload/Resload_" * string(load_year) * ".csv", DataFrame)
for busid in names(resstock_load_profile)
    bus = first(get_components(x -> PSY.get_number(x) == parse(Float64, busid), ACBus, sys))
    name = "Resstock_load_" * busid
    load_ts = resstock_load_profile[!, busid]
    _build_load(sys, bus, name, load_ts, load_year)
end

###### EV Load ##########
ev_load_profile = CSV.read("load_profile/EVload/EVload.csv", DataFrame)
for busid in names(ev_load_profile)
    bus = first(get_components(x -> PSY.get_number(x) == parse(Float64, busid), ACBus, sys))
    name = "EV_load_" * busid
    load_ts = ev_load_profile[!, busid]
    _build_load(sys, bus, name, load_ts, load_year)
end

##########################
### ADD Wind ############
##########################
df_wind = CSV.read("config/wind_config.csv", DataFrame)
wind_profile_raw = CSV.read("wind_profile/Wind" * string(load_year) * ".csv", DataFrame, header=false)
new_header = wind_profile_raw.Column1
transposed_data = permutedims(Matrix(select(wind_profile_raw, Not(:Column1))))
wind_profile = DataFrame(transposed_data, Symbol.(string.(new_header)), makeunique=true)

for (wind_id, wind) in enumerate(eachrow(df_wind))
    name = wind.name
    bus = first(get_components(x -> PSY.get_number(x) == wind.BusId, ACBus, sys))
    rating = wind.rating
    op_cost = RenewableGenerationCost(; variable=CostCurve(; value_curve=LinearCurve(1.0)))
    if wind.name[1:3] == "OSW" && wind.BusId in [79, 80]
        re_ts = wind_profile[!, string(wind.BusId)*"_1"]
    else
        re_ts = wind_profile[!, string(wind.BusId)]
    end
    generator = _add_wind(sys, bus, name, rating, op_cost, re_ts, load_year)
end

##########################
### ADD UPV ############
##########################
df_upv = CSV.read("config/upv_config.csv", DataFrame)
upv_profile_raw = CSV.read("upv_profile/solarUPV" * string(load_year) * ".csv", DataFrame, header=false)
new_header = upv_profile_raw.Column1
transposed_data = permutedims(Matrix(select(upv_profile_raw, Not(:Column1))))
upv_profile = DataFrame(transposed_data, Symbol.(string.(new_header)), makeunique=true)

for (upv_id, upv) in enumerate(eachrow(df_upv))
    name = upv.name
    bus = first(get_components(x -> PSY.get_number(x) == upv.BusId, ACBus, sys))
    rating = upv.rating
    op_cost = RenewableGenerationCost(; variable=CostCurve(; value_curve=LinearCurve(1.0)))
    re_ts = upv_profile[!, string(upv.BusId)]
    generator = _add_upv(sys, bus, name, rating, op_cost, re_ts, load_year)
end

##########################
### ADD DPV ############
##########################
df_dpv = CSV.read("config/dpv_config.csv", DataFrame)
dpv_profile_raw = CSV.read("dpv_profile/solarDPV" * string(load_year) * ".csv", DataFrame, header=false)
new_header = dpv_profile_raw.Column1
transposed_data = permutedims(Matrix(select(dpv_profile_raw, Not(:Column1))))
dpv_profile = DataFrame(transposed_data, Symbol.(string.(new_header)), makeunique=true)

for (dpv_id, dpv) in enumerate(eachrow(df_dpv))
    name = dpv.name
    bus = first(get_components(x -> PSY.get_number(x) == dpv.BusId, ACBus, sys))
    rating = dpv.rating
    op_cost = RenewableGenerationCost(; variable=CostCurve(; value_curve=LinearCurve(1.0)))
    re_ts = dpv_profile[!, string(dpv.BusId)]
    generator = _add_dpv(sys, bus, name, rating, op_cost, re_ts, load_year)
end


##########################
### ADD Storage ############
##########################
df_storage = CSV.read("config/storage_config.csv", DataFrame)

for (sto_id, sto) in enumerate(eachrow(df_storage))
    name = sto.name
    bus = first(get_components(x -> PSY.get_number(x) == sto.BusId, ACBus, sys))
    power_capacity = sto.PowerCap
    energy_capacity = sto.EnergyCap
    efficiency = 0.95
    op_cost = StorageCost(charge_variable_cost=CostCurve(LinearCurve(0.0)))

    storage = _add_storage(sys, bus, name, power_capacity, energy_capacity, efficiency, op_cost)

end

PSY.to_json(sys, "nys2019.json", force=true)