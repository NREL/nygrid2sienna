function save_to_csv(cont, model_name, save_dir=".")
    for (name, df) in cont
        CSV.write(joinpath(save_dir, "$(name)_$(model_name).csv"), df)
    end
end


function export_results_csv(results, variable, stage, path)
    variables = variable
    aux_variables = PSI.read_realized_aux_variables(results)
    parameters = PSI.read_realized_parameters(results)
    duals = PSI.read_realized_duals(results)
    expressions = PSI.read_realized_expressions(results)

    save_to_csv(variables, stage, path)
    save_to_csv(parameters, stage, path)
    save_to_csv(duals, stage, path)
    save_to_csv(aux_variables, stage, path)
    save_to_csv(expressions, stage, path)
    return
end