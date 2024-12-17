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
df_branch = CSV.read("config/branch_config.csv", DataFrame)
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
        println(name)
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
df_iflim = CSV.read("config/interfaceflow_limits.csv", DataFrame)
df_ifmap = CSV.read("config/interfaceflow_mapping.csv", DataFrame)
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
hourly_fuelcost = repeat(fuel_cost, inner=168)
start_date = DateTime("2019-01-01T00:00:00")
n_hours = 8760  # Total hours in a year
hourly_time_range = start_date:Hour(1):(start_date+Hour(n_hours - 1))
hourly_fuelcost = hourly_fuelcost[1:length(hourly_time_range), :]
hourly_fuelcost.TimeStamp = hourly_time_range
for (th_id, th) in enumerate(eachrow(df_thermal))
    name = th.Name
    bus = first(get_components(x -> PSY.get_number(x) == th.BusId, ACBus, sys))
    fuel = fuel_mapping[th.FuelType]
    pmin = th.Pmin
    pmax = th.Pmax
    # if pmin == 0.0
    #     pmin = 0.2 * pmax ## TODO: find better way to estimate pmin
    # end
    heat_rate_curve, fuel_cost_ts = _add_fuel_cost(th.HeatRateLM_1, th.HeatRateLM_0, th.Zone, th.FuelType, pmin, hourly_fuelcost)
    ramp_rate = th.maxRamp10 / 10.0
    pm = pm_mapping[th.UnitType]
    generator = _add_thermal(sys, bus, name, heat_rate_curve, fuel, pmin, pmax, ramp_rate, pm, fuel_cost_ts)
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
    op_cost = ThermalGenerationCost(;
        variable=FuelCurve(; value_curve=LinearCurve(3.0), fuel_cost=1.0),
        fixed=0.0,
        start_up=0.0,
        shut_down=0.0,
    )
    ramp_rate = hy.maxRamp10 / 10.0
    pm = PrimeMovers.HY
    generator = _add_hydro(sys, bus, name=name, cost=op_cost, pmin=pmin, pmax=pmax, ramp_rate=ramp_rate, pm=pm)
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
    zonal_price = filtered_df[1:8760, "LBMP"] ###TODO: this needs to be a time-series
    heat_rate_curve = LinearCurve(1.0, 0)
    ramp_rate = th.maxRampAgc
    pm = PrimeMovers.OT
    generator = _add_thermal(sys, bus, name, heat_rate_curve, fuel, pmin, pmax, ramp_rate, pm, zonal_price)
end

##########################
### ADD Loads ############
##########################
load_profile = CSV.read("Data/load_profiles.csv", DataFrame)
load_year = 2019
for busid in names(load_profile)

    bus = first(get_components(x -> PSY.get_number(x) == parse(Float64, busid), ACBus, sys))
    name = "load_" * busid
    load_ts = load_profile[!, busid]
    # if minimum(load_ts) <= 0.0
    #     load_ts[load_ts.<=0.0] .= 0.1
    # end
    _build_load(sys, bus, name, load_ts, load_year)
end

PSY.to_json(sys, "nys2019.json", force=true)