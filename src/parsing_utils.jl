using PowerSystems
const PSY = PowerSystems

#Function to generate a time array with hourly timestamps for a given year
get_timestamp(year) = DateTime("$(year)-01-01T00:00:00"):Hour(1):DateTime("$(year)-12-31T23:55:00")


function _build_bus(sys, number, name, bustype, angle, magnitude, voltage_limits, base_voltage, area)
    bus = PSY.ACBus(
        number=number,
        name=name,
        bustype=bustype,
        angle=angle,
        magnitude=magnitude,
        voltage_limits=voltage_limits,
        base_voltage=base_voltage,
        area=area,
    )
    add_component!(sys, bus)
end

function _build_lines(sys; frombus::PSY.ACBus, tobus::PSY.ACBus, name, r, x, b, rating)
    # Create a new storage device of the specified type
    device = PSY.Line(
        name=name,
        available=true,
        active_power_flow=rating / 100.0,
        reactive_power_flow=0.0,
        arc=PSY.Arc(from=frombus, to=tobus),
        r=r,
        x=x,
        b=(from=b, to=b),
        rating=rating / 100.0,
        angle_limits=PSY.MinMax((-1.571 * 2, 1.571 * 2)),
    )
    PSY.add_component!(sys, device)
    return device
end


function _build_transformers(sys; frombus::PSY.ACBus, tobus::PSY.ACBus, name, r, x, b, rating)
    # Create a new storage device of the specified type
    device = PSY.Transformer2W(
        name=name,
        available=true,
        active_power_flow=rating / 100.0,
        reactive_power_flow=0.0,
        arc=PSY.Arc(from=frombus, to=tobus),
        r=r,
        x=x,
        primary_shunt=b,
        rating=rating / 100.0,
    )
    PSY.add_component!(sys, device)
    return device
end


function _build_hvdc(sys; frombus::PSY.ACBus, tobus::PSY.ACBus, name, r, x, b, rating)
    # Create a new storage device of the specified type
    device = PSY.TwoTerminalHVDCLine(
        name=name,
        available=true,
        active_power_flow=rating / base_power,
        arc=PSY.Arc(from=frombus, to=tobus),
        active_power_limits_from=PSY.MinMax((-rating / base_power, rating / base_power)),
        active_power_limits_to=PSY.MinMax((-rating / base_power, rating / base_power)),
        reactive_power_limits_from=PSY.MinMax((-rating / base_power, rating / base_power)),
        reactive_power_limits_to=PSY.MinMax((-rating / base_power, rating / base_power)),
        loss=LinearCurve(0.0),
    )
    PSY.add_component!(sys, device)
    return device
end


function _build_interface_flow(sys; name, rating_lb, rating_ub, ifdict)
    # Create a new storage device of the specified type
    service = PSY.TransmissionInterface(
        name=name,
        available=true,
        active_power_flow_limits=PSY.MinMax((rating_lb / 100.0, rating_ub / 100.0)),
        violation_penalty=0.0,
        direction_mapping=ifdict
    )
    contri_devices = PSY.get_components(
        x -> haskey(ifdict, PSY.get_name(x)),
        ACBranch,
        sys,
    )
    PSY.add_service!(sys, service, contri_devices)
    return service
end
function _add_thermal(
    sys,
    bus::PSY.Bus;
    name,
    fuel::PSY.ThermalFuels,
    pmin,
    pmax,
    ramp_rate,
    cost::PSY.OperationalCost,
    pm::PSY.PrimeMovers,
)
    device = PSY.ThermalStandard(
        name=name,
        available=true,
        status=true,
        bus=bus,
        active_power=0.0,
        reactive_power=0.0,
        rating=pmax / base_power,
        active_power_limits=PSY.MinMax((pmin / base_power, pmax / base_power)),
        reactive_power_limits=nothing,
        ramp_limits=(up=ramp_rate / base_power, down=ramp_rate / base_power),
        operation_cost=cost,
        base_power=base_power,
        time_limits=(up=1.0, down=1.0),
        prime_mover_type=pm,
        fuel=fuel,
        time_at_status=999.0,
        ext=Dict{String,Any}(),
    )
    PSY.add_component!(sys, device)

    return device  # Return the newly created component
end

function _add_thermal_cost(heatrate1, heatrate0, zone, fuel, pmin, fuel_table)
    heat_rate_curve = LinearCurve(heatrate1, heatrate0)
    priceTable = fuel_table[29, :] #TODO: Selecting the first week's fuel price now
    fuelPrice = 0.0
    if fuel == "Coal"
        fuelPrice = priceTable["coal_NY"]
    elseif fuel == "Natural Gas"
        fuelPrice = priceTable["NG_A2E"]
        if zone in ["F", "G", "H", "I"]
            fuelPrice = priceTable["NG_F2I"]
        end
        if zone == "K"
            fuelPrice = priceTable["NG_J"]
        end
        if zone == "J"
            fuelPrice = priceTable["NG_K"]
        end
    elseif fuel == "Fuel Oil 2" || fuel == "Kerosene"
        if zone in ["F", "G", "H", "I"]
            fuelPrice = priceTable["FO2_DSNY"]
        else
            fuelPrice = priceTable["FO2_UPNY"]
        end
    elseif fuel == "Fuel Oil 6"
        if zone in ["F", "G", "H", "I"]
            fuelPrice = priceTable["FO6_DSNY"]
        else
            fuelPrice = priceTable["FO6_UPNY"]
        end
    else
        error("Error: Undefined fuel type!")
    end
    fuel_cost = fuelPrice
    fuel_curve = FuelCurve(; value_curve=heat_rate_curve, fuel_cost=fuel_cost)
    startup_cost = pmin * heatrate1 * fuel_cost
    op_cost = ThermalGenerationCost(;
        variable=fuel_curve,
        fixed=0.0,
        start_up=startup_cost,
        shut_down=0.0,
    )
    return op_cost
end

function _add_nuclear(
    sys,
    bus::PSY.Bus;
    name,
    fuel::PSY.ThermalFuels,
    pmin,
    pmax,
    ramp_rate,
    cost::PSY.OperationalCost,
    pm::PSY.PrimeMovers,
)
    device = PSY.ThermalStandard(
        name=name,
        available=true,
        status=true,
        bus=bus,
        active_power=0.0,
        reactive_power=0.0,
        rating=pmax / base_power,
        active_power_limits=PSY.MinMax((pmin / base_power, pmax / base_power)),
        reactive_power_limits=nothing,
        ramp_limits=(up=ramp_rate / base_power, down=ramp_rate / base_power),
        operation_cost=cost,
        base_power=base_power,
        time_limits=(up=1.0, down=1.0),
        prime_mover_type=pm,
        fuel=fuel,
        time_at_status=999.0,
        ext=Dict{String,Any}(),
    )
    PSY.add_component!(sys, device)

    return device  # Return the newly created component
end

function _add_hydro(
    sys,
    bus::PSY.Bus;
    name,
    pmin,
    pmax,
    ramp_rate,
    cost::PSY.OperationalCost,
    pm::PSY.PrimeMovers,
)
    device = PSY.ThermalStandard(
        name=name,
        available=true,
        bus=bus,
        status=true,
        active_power=pmax / base_power,
        reactive_power=0.0,
        rating=pmax / base_power,
        active_power_limits=PSY.MinMax((pmin / base_power, pmax / base_power)),
        reactive_power_limits=nothing,
        ramp_limits=(up=ramp_rate / base_power, down=ramp_rate / base_power),
        operation_cost=cost,
        base_power=base_power,
        time_limits=(up=1.0, down=1.0),
        prime_mover_type=pm,
        fuel=ThermalFuels.OTHER,
        ext=Dict{String,Any}(),
    )
    PSY.add_component!(sys, device)

    return device  # Return the newly created component
end
#Function builds a wind component in the pwoer system. it takes arguments such as the system ('sys'), the bus wheree the wind component is located ('bus::PYS.Bus), 
#the name of the wind component ('name'), its rating, time series data for wind genration ('re_ts') and the year for which the data is provided ('load_year')
function _add_wind(sys, bus::PSY.Bus, name, rating, op_cost, re_ts, load_year)
    #creates wind component using "RenewableDispatch construcotr from PSY package
    wind = PSY.RenewableDispatch(
        name=name,  #set name of wind component            
        available=true, #marks component as available 
        bus=bus, #assigns bus to which wind component is connected 
        active_power=rating / 100.0, #sets the active power wind component base on its rating 
        reactive_power=0.0, #sets reative power of wind component to zero 
        rating=rating / 100.0, #sets rating of wind component 
        prime_mover_type=PSY.PrimeMovers.WT, #sets the prime mover type of wind turbine
        reactive_power_limits=(min=0.0, max=1.0 * rating / 100.0), #sets the reative power limits 
        power_factor=1.0, #sets the operation cost 
        operation_cost=op_cost,
        base_power=100, #sets base power to 100 
    )
    # Add the wind component to the power system
    add_component!(sys, wind)

    # Add a time series for the maximum active power based on the input time series data
    PSY.add_time_series!(
        sys,
        wind,
        PSY.SingleTimeSeries(
            "max_active_power",
            TimeArray(get_timestamp(load_year), re_ts / maximum(re_ts)),
            scaling_factor_multiplier=PSY.get_max_active_power,
        )
    )
    return wind  #return the newly created wind component
end

#Function builds a solar component in the power system. Takes similar arguments to wind function. 
function _add_upv(sys, bus::PSY.Bus, name, rating, op_cost, re_ts, load_year)
    #creates solar component using the 'RenewableDispatch' constructor from the 'PSY' package 
    solar = PSY.RenewableDispatch(
        name=name,  #sets name of solar component             
        available=true,   #marks the component as available       
        bus=bus, # assigns bus to which the solar ompnent is connected
        active_power=rating / 100.0, # sets the active power of the solar component based on its rating 
        reactive_power=0.0, #sets reatie power of solar component to zero 
        rating=rating / 100.0, #sets rating of solar component 
        prime_mover_type=PSY.PrimeMovers.PVe, #sets the prime mover type as photovoltaic 
        reactive_power_limits=(min=0.0, max=1.0 * rating / 100.0), #sets the reactive power limits
        power_factor=1.0, #sets the power factor to 1
        operation_cost=op_cost, #sets the operation cost of the solar component 
        base_power=100, #sets the base power to 0 
    )
    #add the solar component to the power system
    add_component!(sys, solar)

    PSY.add_time_series!(
        sys,
        solar,
        PSY.SingleTimeSeries(
            "max_active_power",
            TimeArray(get_timestamp(load_year), re_ts / rating),
            scaling_factor_multiplier=PSY.get_max_active_power,
        )
    )

    return solar  #return the newly created solar component
end

function _add_dpv(sys, bus::PSY.Bus, name, rating, op_cost, re_ts, load_year)
    #creates solar component using the 'RenewableDispatch' constructor from the 'PSY' package 
    solar = PSY.RenewableNonDispatch(
        name=name,  #sets name of solar component             
        available=true,   #marks the component as available       
        bus=bus, # assigns bus to which the solar ompnent is connected
        active_power=rating / 100.0, # sets the active power of the solar component based on its rating 
        reactive_power=0.0, #sets reatie power of solar component to zero 
        rating=rating / 100.0, #sets rating of solar component 
        prime_mover_type=PSY.PrimeMovers.PVe, #sets the prime mover type as photovoltaic 
        power_factor=1.0, #sets the power factor to 1
        base_power=100, #sets the base power to 0 
    )
    #add the solar component to the power system
    add_component!(sys, solar)

    PSY.add_time_series!(
        sys,
        solar,
        PSY.SingleTimeSeries(
            "max_active_power",
            TimeArray(get_timestamp(load_year), re_ts / rating),
            scaling_factor_multiplier=PSY.get_max_active_power,
        )
    )

    return solar  #return the newly created solar component
end
#Function builds a battery component in the power system. it takes arugments such as system, type of storage device ('::Type{T}), 
#the bus where the battery component is loacted, its name, energy capacity, rating and efficiency
function _add_storage(sys, bus::PSY.Bus, name, power_capacity, energy_capacity, efficiency, op_cost)
    # Create a new storage device of the specified type
    device = PSY.EnergyReservoirStorage(
        name=name,                         # Set the name for the new component
        available=true,                    # Mark the component as available
        bus=bus,                           # Assign the bus to the component
        prime_mover_type=PSY.PrimeMovers.BA,    # Set the prime mover to Battery
        storage_technology_type=StorageTech.LIB,
        storage_capacity=energy_capacity / 100.0,
        storage_level_limits=(min=0.1, max=1.0),
        initial_storage_capacity_level=0.5,  # Set initial energy level
        rating=power_capacity / 100.0,                     # Set the rating
        active_power=power_capacity / 100.0,               # Set active power equal to rating
        input_active_power_limits=(min=0.0, max=power_capacity / 100.0),  # Set input active power limits
        output_active_power_limits=(min=0.0, max=power_capacity / 100.0),  # Set output active power limits
        efficiency=(in=efficiency, out=1.0),  # Set efficiency
        reactive_power=0.0,                # Set reactive power
        reactive_power_limits=nothing,      # No reactive power limits
        base_power=100.0,                    # Set base power
        operation_cost=op_cost
    )

    # Add the battery component to the power system
    PSY.add_component!(sys, device)

    return device  # Return the newly created battery component
end

#Function builds a load component in the power system. it takes arugments such as system, bus, name, load_ts and load_eyear, 
function _build_load(sys, bus::PSY.Bus, name, load_ts, load_year)

    if maximum(load_ts) == 0.0
        maxload = minimum(load_ts) / base_power
    else
        maxload = maximum(load_ts) / base_power
    end
    # Create a new load component with the specified parameters
    load = PSY.StandardLoad(
        name=name,                         # Set the name for the new component
        available=true,                    # Mark the component as available
        bus=bus,                           # Assign the bus to the component
        base_power=100.0,                  # Base power of the load component (in kW)
        max_constant_active_power=maxload,  # Maximum constant active power of the load component (scaled from the maximum of the load time series)
    )

    # Add the load component to the power system model
    add_component!(sys, load)

    ### The issue was that the name of the time series and the name in the renewable config doesn't match. Now they matched but we should think about how to name things later to make it easier to track.
    # Add a time series for the load, scaling the load based on the maximum active power specified by the time series
    #=
    PSY.add_time_series!(
        sys,
        load,
        PSY.SingleTimeSeries(
            "max_active_power",  # Name of the time series for the maximum active power
            TimeArray(get_timestamp(load_year), load_ts);  # Time series data for the load
            scaling_factor_multiplier=PSY.get_max_active_power,  # Scaling factor based on the maximum active power
        ),
    )

    =#
    if maximum(load_ts) == 0.0
        PSY.add_time_series!(
            sys,
            load,
            PSY.SingleTimeSeries(
                "max_active_power",
                TimeArray(get_timestamp(load_year), load_ts / minimum(load_ts)),
                scaling_factor_multiplier=PSY.get_max_active_power,
            )
        )
    else
        PSY.add_time_series!(
            sys,
            load,
            PSY.SingleTimeSeries(
                "max_active_power",
                TimeArray(get_timestamp(load_year), load_ts / maximum(load_ts)),
                scaling_factor_multiplier=PSY.get_max_active_power,
            )
        )
    end

    return load  # Return the newly created load component
end


