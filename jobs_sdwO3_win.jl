include("xml_parameters.jl")

julia_code_file = "C:/Users/carsten/Desktop/sciebo/codes/julia-sdw-dqmc/dqmc.jl"
output_root = "C:/Users/carsten/Desktop"
lattice_dir = "C:/Users/carsten/Desktop/sciebo/lattices"

if !isdir(output_root) mkdir(output_root) end
cd(output_root)

for L in [6]
for beta in [20]
for dt in [0.1]
for (k, seed) in enumerate([55796])
W = L # square lattice

dir = "L_$(L)"
if !isdir(dir) mkdir(dir) end
cd(dir)
prefix = "sdwO3_L_$(L)_B_$(beta)_dt_$(dt)_$(k)"

mkdir(prefix)
cd(prefix)

p = Dict{Any, Any}("LATTICE_FILE"=>["$lattice_dir/honeycomb_L_$(L)_W_$(W).xml"], "SLICES"=>[Int(beta / dt)], "DELTA_TAU"=>[dt], "SAFE_MULT"=>[10], "U"=>[1.0], "R"=>[8.0, 9.0, 10.0], "LAMBDA"=>[3., 4., 5.], "HOPPINGS"=>["1.0,0.5,0.5,1.0"], "MU"=>[0.5], "SEED"=>[55796], "BOX_HALF_LENGTH"=>[0.2])
p["THERMALIZATION"] = 1024
p["MEASUREMENTS"] = 8192
parameterset2xml(p, prefix)


job_cheops = """
    #!/bin/bash -l
    #SBATCH --nodes=1
    #SBATCH --ntasks=1
    #SBATCH --mem=1gb
    #SBATCH --time=24:00:00
    #SBATCH --account=UniKoeln

    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
    source ~/.bashrc
    cd $(output_root)/$(dir)/$(prefix)/
    julia $(julia_code_file) $(prefix) \$\{SLURM_ARRAY_TASK_ID\}
    """
f = open("$(prefix).sh", "w")
write(f, job_cheops)
close(f)

cd("../..")
end
end
end
end
