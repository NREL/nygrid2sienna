thermalgen = variables["ActivePowerVariable__ThermalStandard"]
thermalgen = select!(thermalgen, Not(:DateTime))
gen = DataFrame([names(thermalgen)], :auto)
gen[!, "Generation"] = vec(permutedims(Matrix(thermalgen)))

gen_m = CSV.read("Data/gen_matlab.csv", DataFrame, header=false)

using MAT
mpc = matread("Data/resultOPF_20190718_14.mat")
mpc = mpc["resultOPF"]
branch = mpc["branch"]
bus = mpc["bus"]
dcline = mpc["dcline"]
gencost = mpc["gencost"]
ifs = mpc["if"]
iflims = ifs["lims"]
generation = mpc["gen"]
CSV.write("branch_0101.csv", Tables.table(branch), writeheader=false)
CSV.write("gen_0101.csv", Tables.table(generation), writeheader=false)
CSV.write("gencost_0718.csv", Tables.table(gencost), writeheader=false)
# gen_m[!, "Column2"] = vec(generation[:, 2])

gen_m[!, "Column2"] = generation[:, 2]
merged_gen = DataFrames.leftjoin(gen, gen_m, on=:x1 => :Column1)
CSV.write("Data/merged_gen.csv", merged_gen)



