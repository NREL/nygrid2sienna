using Revise
using PowerSimulations
using Dates
using Logging
using PowerGraphics
logger = configure_logging(console_level=Logging.Info)
const PSI = PowerSimulations
const PSY = PowerSystems
const PG = PowerGraphics
using TimeSeries
using JuMP
# using HiGHS
using Xpress
using StorageSystemsSimulations
using HydroPowerSimulations
using DataFrames
using CSV

# Include the parsing utilities script
include("parsing_utils.jl")
include("post_process.jl")
# Simulation setup parameters
sim_name = "clcpa2040test"

output_dir = "TestRun"
interval = 24
horizon = 24
steps = 365

# Check if the output directory exists, create if not
if !ispath(output_dir)
    mkpath(output_dir)
end

# Replace the HiGHS optimizer with Gurobi
# solver = optimizer_with_attributes(
#     Gurobi.Optimizer,
#     "TimeLimit" => 10000.0,     # Set the maximum solver time (in seconds)
#     "OutputFlag" => 1,          # Enable logging to console
#     "MIPGap" => 1e-2            # Set the relative MIP gap tolerance
# )

solver = optimizer_with_attributes(
    Xpress.Optimizer,
    "MIPRELSTOP" => 1e-3, # Set the relative mip gap tolerance
    "OUTPUTLOG" => 1, # Enable logging
    "MAXTIME" => 60, # Set the maximum solver time (in seconds)
    "THREADS" => 8, # Set the number of solver threads to use
    # "MAXMEMORYSOFT" => 30000, # Set the maximum amount of memory the solver can use (in MB)
)

# solver = optimizer_with_attributes(
#     HiGHS.Optimizer,
#     "time_limit" => 600.0,     # Set the maximum solver time (in seconds)
#     # "threads" => 12,       
#     "log_to_console" => true,  # Enable logging
#     "mip_abs_gap" => 1e-3,      # Set the relative MIP gap tolerance
# )
# Create a power system
#sys = System(sys_name) - was defined in SystemParsing.jl

# Transform time series data for the specified horizon and interval
PSY.transform_single_time_series!(sys, Hour(horizon), Hour(interval))

# Create a unit commitment template using DC power flow model
template_uc = PSI.template_unit_commitment(; network=NetworkModel(PSI.PTDFPowerModel, use_slacks=false, PTDF_matrix=PTDF(sys)))
# template_uc = PSI.template_unit_commitment(; network=NetworkModel(PSI.CopperPlatePowerModel, use_slacks=false, PTDF_matrix=PTDF(sys)))
# Set device models for different components
set_device_model!(template_uc, ThermalStandard, ThermalBasicDispatch)
set_device_model!(template_uc, StandardLoad, StaticPowerLoad)
set_device_model!(template_uc, EnergyReservoirStorage, StorageDispatchWithReserves)
set_device_model!(template_uc, Transformer2W, StaticBranch)
set_device_model!(template_uc, Line, StaticBranch)
set_device_model!(template_uc, TwoTerminalHVDCLine, HVDCTwoTerminalLossless)
set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
set_service_model!(template_uc, TransmissionInterface, ConstantMaxInterfaceFlow)

# Create simulation models
models = SimulationModels(
    decision_models=[
        DecisionModel(
            template_uc,
            sys,
            name="UC",
            optimizer=solver,
            initialize_model=false,
            optimizer_solve_log_print=true,
            check_numerical_bounds=true,
            warm_start=true,
            store_variable_names=true,
        ),
    ],
)

# Create a simulation sequence
sequence = SimulationSequence(models=models, ini_cond_chronology=InterProblemChronology())

# Create a simulation object
sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
    # initial_time=DateTime("2019-07-18T14:00:00")
)

# Build and execute the simulation
build!(sim, serialize=true)
execute!(sim, enable_progress_bar=true)

model = get_simulation_model(sim, :UC)
JuMP.write_to_file(model.internal.container.JuMPmodel, "model.lp")
results = SimulationResults(sim; ignore_status=true);
results_uc = get_decision_problem_results(results, "UC");
set_system!(results_uc, sys);
variables = PSI.read_realized_variables(results_uc)
export_results_csv(results_uc, variables, "ED", joinpath(results.path, "results"))
# PSI.compute_conflict!(model.internal.container)
plotlyjs()
p = PG.plot_fuel(
    results_uc;
    curtailment=true,
    display=false,
    title="all_plants_case_dispatch", # saved plot will saved with the title as its name
    slacks=true,
    # generator_mapping_file="generator_mapping.yaml",
    # palette=PG.load_palette("color.yaml"),
    save=".",
    format="html"
);
