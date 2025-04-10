using DataFrames

# Step 1: Create copies and rename columns using rename!
df_from = deepcopy(df_bus_origin)
DataFrames.rename!(df_from, :busIdx => :from)

df1 = leftjoin(df_branch_origin, df_from, on=:from)
DataFrames.rename!(df1, :zone => :from_zone)

# Step 2: Repeat for :to
df_to = deepcopy(df_bus_origin)
DataFrames.rename!(df_to, :busIdx => :to)

df2 = leftjoin(df1, df_to, on=:to, makeunique=true)
DataFrames.rename!(df2, :zone => :to_zone)
df2 = filter(row -> row.from_zone != row.to_zone, df2)
# Step 3: Group and sum
df_zone_ratings = combine(groupby(df2, [:from_zone, :to_zone]),
    :rating_A => sum => :total_rating)

# Optional: sort for readability
sort!(df_zone_ratings, [:from_zone, :to_zone])


# Step 0: Add time index if needed
load_profile_with_time = copy(load_profile)
load_profile_with_time.time = 1:nrow(load_profile)

# Step 1: Get valid bus columns (intersecting with known busIdx)
valid_buses = string.(df_bus_origin.busIdx)
bus_cols = intersect(names(load_profile_with_time), valid_buses)

# Step 2: Stack
df_long = stack(load_profile_with_time, bus_cols, variable_name=:busIdx, value_name=:load)
df_long.busIdx = parse.(Int, df_long.busIdx)

# Step 3–5: same as before
df_with_zone = leftjoin(df_long, df_bus_origin[:, [:busIdx, :zone]], on=:busIdx)
grouped = combine(groupby(df_with_zone, [:time, :zone]), :load => sum => :zonal_load)
zonal_load_profile = unstack(grouped, :time, :zone, :zonal_load)
# Step 6: Rename columns
CSV.write("zonal_load_profile.csv", zonal_load_profile)