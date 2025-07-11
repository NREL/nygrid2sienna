thermalgen = variables["ActivePowerVariable__ThermalStandard"]
thermalgen = select!(thermalgen, Not(:DateTime))
gen = DataFrame([names(thermalgen)], :auto)
gen[!, "Generation"] = vec(permutedims(Matrix(thermalgen)))

gen_m = CSV.read("Data/gen_matlab.csv", DataFrame, header=false)

using MAT
mpc = matread("Data/resultOPF_20190101_00.mat")
mpc = mpc["resultOPF"]
dcline = mpc["dcline"]
gencost = mpc["gencost"]
ifs = mpc["if"]
iflims = ifs["lims"]
generation = mpc["gen"]
# gen_m[!, "Column2"] = vec(generation[:, 2])

gen_m[!, "Column2"] = generation[:, 2]
merged_gen = DataFrames.leftjoin(gen, gen_m, on=:x1 => :Column1)
CSV.write("Data/merged_gen.csv", merged_gen)



