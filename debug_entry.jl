# dqmc.jl called with arguments: sdwO3_L_4_B_2_dt_0.1_1 ${SLURM_ARRAY_TASK_ID}
# start_time = now()
# println("Started: ", Dates.format(start_time, "d.u yyyy HH:MM"))

using BenchmarkTools
using Helpers
using Git
include("linalg.jl")
include("parameters.jl")
include("xml_parameters.jl")
include("lattice.jl")
include("checkerboard.jl")
include("interactions.jl")
include("action.jl")
include("stack.jl")
include("local_updates.jl")
include("global_updates.jl")
include("observable.jl")
include("boson_measurements.jl")
include("fermion_measurements.jl")
# include("tests/tests_gf_functions.jl")

mutable struct Analysis
    acc_rate::Float64
    acc_rate_global::Float64
    prop_global::Int
    acc_global::Int

    Analysis() = new()
end

ARGS = ["sdwO3_L_4_B_2_dt_0.1_1", 1]
prefix = convert(String, ARGS[1])
idx = 1
try
  idx = parse(Int, ARGS[2]) # SLURM_ARRAY_TASK_ID
end
output_file = prefix * ".task" * string(idx) * ".out.h5"

# hdf5 write test
f = HDF5.h5open(output_file, "w")
f["params/TEST"] = 42
close(f)

# load parameters xml
params = Dict{Any, Any}()
try
  println("Prefix is ", prefix, " and idx is ", idx)
  params = xml2parameters(prefix * ".task" * string(idx) * ".in.xml")

  # Check and store code version (git commit)
  if haskey(params,"GIT_COMMIT_DQMC") && Git.head(dir=dirname(@__FILE__)) != params["GIT_COMMIT_DQMC"]
    warn("Git commit in input xml file does not match current commit of code.")
  end
  params["GIT_COMMIT_DQMC"] = Git.head(dir=dirname(@__FILE__))

  parameters2hdf5(params, output_file)
catch e
  println(e)
end


### PARAMETERS
p = Parameters()
p.output_file = output_file
p.thermalization = parse(Int, params["THERMALIZATION"])
p.measurements = parse(Int, params["MEASUREMENTS"])
p.slices = parse(Int, params["SLICES"])
p.delta_tau = parse(Float64, params["DELTA_TAU"])
p.safe_mult = parse(Int, params["SAFE_MULT"])
p.lattice_file = params["LATTICE_FILE"]
srand(parse(Int, params["SEED"]))
p.mu = parse(Float64, params["MU"])
p.lambda = parse(Float64, params["LAMBDA"])
p.r = parse(Float64, params["R"])
p.c = parse(Float64, params["C"])
p.u = parse(Float64, params["U"])
p.global_updates = haskey(params,"GLOBAL_UPDATES")?parse(Bool, lowercase(params["GLOBAL_UPDATES"])):true;
p.beta = p.slices * p.delta_tau
p.flv = 4
if haskey(params,"BOX_HALF_LENGTH")
  p.box = Uniform(-parse(Float64, params["BOX_HALF_LENGTH"]),parse(Float64, params["BOX_HALF_LENGTH"]))
else
  p.box = Uniform(-0.2,0.2)
end
if haskey(params,"BOX_GLOBAL_HALF_LENGTH")
  p.box_global = Uniform(-parse(Float64, params["BOX_GLOBAL_HALF_LENGTH"]),parse(Float64, params["BOX_GLOBAL_HALF_LENGTH"]))
else
  p.box_global = Uniform(-0.1,0.1)
end
if haskey(params,"GLOBAL_RATE")
  p.global_rate = parse(Int64, params["GLOBAL_RATE"])
else
  p.global_rate = 5
end

### LATTICE
l = Lattice()
Lpos = maximum(search(p.lattice_file,"L_"))+1
l.L = parse(Int, p.lattice_file[Lpos:Lpos+minimum(search(p.lattice_file[Lpos:end],"_"))-2])
l.t = reshape([parse(Float64, f) for f in split(params["HOPPINGS"], ',')],(2,2))
init_lattice_from_filename(params["LATTICE_FILE"], l)
println("Initializing neighbor-tables")
init_neighbors_table(p,l)
init_time_neighbors_table(p,l)
println("Initializing hopping exponentials")
init_hopping_matrix_exp(p,l)
init_checkerboard_matrices(p,l)

s = Stack()
a = Analysis()

println("\nInitializing HS field")
p.hsfield = rand(3,l.sites,p.slices)
println("Initializing boson action\n")
p.boson_action = calculate_boson_action(p,l)

# stack init and test
initialize_stack(s, p, l)
println("Building stack")
build_stack(s, p, l)
println("Initial propagate: ", s.current_slice, " ", s.direction)
propagate(s, p, l)

include("tests\\tests_gf_stabilization.jl")