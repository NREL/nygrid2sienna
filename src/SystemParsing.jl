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
sys = PSY.System(base_power)
set_units_base_system!(sys, PSY.UnitSystem.NATURAL_UNITS)

df_bus = CSV.read("config/bus_config.csv", DataFrame)

##########################
##### ADD LOAD ZONE ######
##########################
zone_list = unique(df_bus[!, "zone"])
for zone in zone_list
    z = PSY.LoadZone(zone, 0.0, 0.0)
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
    load_zone = get_component(PSY.LoadZone, sys, bus.zone)
    _build_bus(sys, number, name, bustype, angle, magnitude, voltage_limits, base_voltage, load_zone) #TODO: bus voltage disabled. Will come back to this and fix it for transformers and interface flows.
end