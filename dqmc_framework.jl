# -------------------------------------------------------
#                    Abstract types
# -------------------------------------------------------
abstract type Checkerboard end
abstract type CBTrue <: Checkerboard end
abstract type CBFalse <: Checkerboard end
abstract type CBGeneric <: CBTrue end
abstract type CBAssaad <: CBTrue end

abstract type AbstractDQMC{C<:Checkerboard, GreensEltype<:Number, HoppingEltype<:Number} end

isdefined(:DQMC_CBTrue) || (global const DQMC_CBTrue = AbstractDQMC{C} where C<:CBTrue)
isdefined(:DQMC_CBFalse) || (global const DQMC_CBFalse = AbstractDQMC{C} where C<:CBFalse)



# -------------------------------------------------------
#                    Includes
# -------------------------------------------------------
using Helpers
using MonteCarloObservable
using TimerOutputs
using FFTW # v.0.6 naming bug
using Distributions
using HDF5
using LightXML
using Iterators
using Base.Dates

# to avoid namespace conflict warnings
import Distributions: params
import LightXML: root, name

isdefined(:TIMING) || (global const TIMING = false)
macro mytimeit(exprs...)
    if TIMING
        return :(@timeit($(esc.(exprs)...)))
    else
        return esc(exprs[end])
    end
end

include("parameters.jl")
include("lattice.jl")
include("stack.jl")
include("slice_matrices.jl")
include("linalg.jl")
include("hoppings.jl")
include("hoppings_checkerboard.jl")
include("hoppings_checkerboard_generic.jl")
include("interactions.jl")
include("action.jl")
include("local_updates.jl")
include("global_updates.jl")
# include("observable.jl")
include("boson_measurements.jl")
include("fermion_measurements.jl")



# -------------------------------------------------------
#                    Concrete types
# -------------------------------------------------------
mutable struct Analysis
  acc_rate::Float64
  acc_rate_global::Float64
  prop_global::Int
  acc_global::Int
  to::TimerOutputs.TimerOutput

  Analysis() = new(0.0,0.0,0,0,TimerOutput())
end

mutable struct DQMC{C<:Checkerboard, GreensEltype<:Number, HoppingEltype<:Number} <: AbstractDQMC{C, GreensEltype, HoppingEltype}
  p::Params
  l::Lattice{HoppingEltype}
  s::Stack{GreensEltype}
  a::Analysis
end

DQMC(p::Params) = begin
  CB = CBFalse

  # choose checkerboard variant
  if p.chkr
    if p.Nhoppings == "none" && p.NNhoppings == "none"
      CB = iseven(p.L) ? CBAssaad : CBGeneric
    else
      CB = CBGeneric
    end
  end
  println()
  @show CB
  @show p.hoppings
  @show p.Nhoppings
  @show p.NNhoppings
  @show p.lattice_file
  println()

  ### SET DATATYPES
  G = Complex128
  H = Complex128
  if !p.Bfield
    H = Float64;
    G = p.opdim > 1 ? Complex128 : Float64; # O(1) -> real GF
  end

  mc = DQMC{CB,G,H}(p, Lattice{H}(), Stack{G}(), Analysis())
  load_lattice(mc)
  mc
end

# type helpers
@inline geltype(mc::DQMC{CB, G, H}) where {CB, G, H} = G
@inline heltype(mc::DQMC{CB, G, H}) where {CB, G, H} = H
@inline cbtype(mc::DQMC{CB, G, H}) where {CB, G, H} = CB



# -------------------------------------------------------
#                  Monte Carlo
# -------------------------------------------------------
function init!(mc::DQMC)
  srand(mc.p.seed); # init RNG
  init!(mc, rand(mc.p.opdim,mc.l.sites,mc.p.slices), false)
end
function init!(mc::DQMC, start_conf, init_seed=true)
  const a = mc.a
  @mytimeit a.to "init mc" begin
  init_seed && srand(mc.p.seed); # init RNG

  # Init hsfield
  println("\nInitializing HS field")
  mc.p.hsfield = start_conf
  println("Initializing boson action\n")
  mc.p.boson_action = calc_boson_action(mc)

  # stack init and test
  initialize_stack(mc)
  println("Building stack")
  build_stack(mc)
  println("Initial propagate: ", mc.s.current_slice, " ", mc.s.direction)
  propagate(mc)
  end

  TIMING && show(TimerOutputs.flatten(a.to); allocations = true)
  nothing
end

function run!(mc::DQMC)
  println("\n\nMC Thermalize - ", mc.p.thermalization*2)
  flush(STDOUT)
  thermalize!(mc)

  h5open(mc.p.output_file, "r+") do f
    HDF5.has(f, "resume/box") && o_delete(f, "resume/box")
    HDF5.has(f, "resume/box_global") && o_delete(f, "resume/box_global")
    write(f, "resume/box", mc.p.box.b)
    write(f, "resume/box_global", mc.p.box_global.b)
  end

  println("\n\nMC Measure - ", mc.p.measurements*2)
  flush(STDOUT)
  measure!(mc)
  nothing
end

function resume!(mc::DQMC, lastconf, prevmeasurements::Int)
  const p = mc.p

  # Init hsfield
  println("\nLoading last HS field")
  p.hsfield = copy(lastconf)
  println("Initializing boson action\n")
  p.boson_action = calc_boson_action(mc)

  h5open(p.output_file, "r") do f
    box = read(f, "resume/box")
    box_global = read(f, "resume/box_global")
    p.box = Uniform(-box, box)
    p.box_global = Uniform(-box_global, box_global)
  end

  println("\n\nMC Measure (resuming) - ", p.measurements*2, " (total $((p.measurements + prevmeasurements)*2))")
  flush(STDOUT)
  measure!(mc, prevmeasurements)

  nothing
end











function thermalize!(mc::DQMC)
  const a = mc.a
  const p = mc.p

  a.acc_rate = 0.0
  a.acc_rate_global = 0.0
  a.prop_global = 0
  a.acc_global = 0

  reset_timer!(a.to)
  for i in (p.prethermalized+1):p.thermalization
    tic()
    @timeit a.to "udsweep" for u in 1:2 * p.slices
      update(mc, i)
    end
    udswdur = toq()
    @printf("\tsweep duration: %.4fs\n", udswdur/2)
    flush(STDOUT)

    if mod(i, 10) == 0
      a.acc_rate = a.acc_rate / (10 * 2 * p.slices)
      a.acc_rate_global = a.acc_rate_global / (10 / p.global_rate)
      println("\n\t", i*2)
      @printf("\t\tsweep dur (total mean): %.4fs\n", TimerOutputs.time(a.to["udsweep"])/2 *10.0^(-9)/TimerOutputs.ncalls(a.to["udsweep"]))
      @printf("\t\tacc rate (local) : %.1f%%\n", a.acc_rate*100)
      if p.global_updates
        @printf("\t\tacc rate (global): %.1f%%\n", a.acc_rate_global*100)
        @printf("\t\tacc rate (global, overall): %.1f%%\n", a.acc_global/a.prop_global*100)
      end

      # adaption (only during thermalization)
      if a.acc_rate < 0.5
        @printf("\t\tshrinking box: %.2f\n", 0.9*p.box.b)
        p.box = Uniform(-0.9*p.box.b,0.9*p.box.b)
      else
        @printf("\t\tenlarging box: %.2f\n", 1.1*p.box.b)
        p.box = Uniform(-1.1*p.box.b,1.1*p.box.b)
      end

      if p.global_updates
        if a.acc_global/a.prop_global < 0.5
          @printf("\t\tshrinking box_global: %.2f\n", 0.9*p.box_global.b)
          p.box_global = Uniform(-0.9*p.box_global.b,0.9*p.box_global.b)
        else
          @printf("\t\tenlarging box_global: %.2f\n", 1.1*p.box_global.b)
          p.box_global = Uniform(-1.1*p.box_global.b,1.1*p.box_global.b)
        end
      end
      a.acc_rate = 0.0
      a.acc_rate_global = 0.0
      println()
      flush(STDOUT)
    end

    # Save thermal configuration for "resume"
    if i%p.write_every_nth == 0
      h5open(mc.p.output_file, "r+") do f
        HDF5.has(f, "thermal_init/conf") && HDF5.o_delete(f, "thermal_init/conf")
        HDF5.has(f, "thermal_init/prethermalized") && HDF5.o_delete(f, "thermal_init/prethermalized")
        write(f, "thermal_init/conf", mc.p.hsfield)
        write(f, "thermal_init/prethermalized", i)
        (i == p.thermalization) && saverng(p.output_file; group="thermal_init/rng") # for future features
      end
    end

    if now() >= p.walltimelimit
      println("Approaching wall-time limit. Safely exiting.")
      exit(42)
    end

  end

  if TIMING 
    # display(a.to);
    show(TimerOutputs.flatten(a.to); allocations = true)
    # save(p.output_file[1:end-10]*"timings.jld", "to", a.to); # TODO
    rm(p.output_file)
    exit();
  end
  nothing
end






function measure!(mc::DQMC, prevmeasurements=0)
  const a = mc.a
  const l = mc.l
  const p = mc.p
  const s = mc.s

  initialize_stack(mc)
  println("Renewing stack")
  build_stack(mc)
  println("Initial propagate: ", s.current_slice, " ", s.direction)
  propagate(mc)

  cs = choose_chunk_size(mc)

  configurations = Observable(typeof(p.hsfield), "configurations"; alloc=cs, inmemory=false, outfile=p.output_file, dataset="obs/configurations")
  greens = Observable(typeof(mc.s.greens), "greens"; alloc=cs, inmemory=false, outfile=p.output_file, dataset="obs/greens")
  occ = Observable(Float64, "occupation"; alloc=cs, inmemory=false, outfile=p.output_file, dataset="obs/occupation")
  boson_action = Observable(Float64, "boson_action"; alloc=cs, inmemory=false, outfile=p.output_file, dataset="obs/boson_action")

  i_start = 1
  i_end = p.measurements

  if p.resume
    restorerng(p.output_file; group="resume/rng")
    togo = mod1(prevmeasurements, p.write_every_nth)-1
    i_start = prevmeasurements-togo+1
    i_end = p.measurements + prevmeasurements
  end

  acc_rate = 0.0
  acc_rate_global = 0.0
  for i in i_start:i_end
    @timeit a.to "udsweep" for u in 1:2 * p.slices
      update(mc, i)

      # if s.current_slice == 1 && s.direction == 1 && (i-1)%p.write_every_nth == 0 # measure criterium
      if s.current_slice == p.slices && s.direction == -1 && (i-1)%p.write_every_nth == 0 # measure criterium
        dumping = (length(boson_action)+1)%cs == 0
        dumping && println("Dumping... (2*i=$(2*i))")
        add!(boson_action, p.boson_action)

        add!(configurations, p.hsfield)
        
        # fermionic quantities
        g = wrap_greens(mc,mc.s.greens,mc.s.current_slice,1)
        effective_greens2greens!(mc, g)
        # compare(g, measure_greens(mc))
        add!(greens, g)
        add!(occ, occupation(mc, g))

        dumping && saverng(p.output_file; group="resume/rng")
        dumping && println("Dumping block of $cs datapoints was a success")
        flush(STDOUT)
      end
    end

    if mod(i, 100) == 0
      a.acc_rate = a.acc_rate / (100 * 2 * p.slices)
      a.acc_rate_global = a.acc_rate_global / (100 / p.global_rate)
      println("\t", i*2)
      @printf("\t\tsweep dur (total mean): %.4fs\n", TimerOutputs.time(a.to["udsweep"])/2 *10.0^(-9)/TimerOutputs.ncalls(a.to["udsweep"]))
      @printf("\t\tacc rate (local) : %.1f%%\n", a.acc_rate*100)
      if p.global_updates
        @printf("\t\tacc rate (global): %.1f%%\n", a.acc_rate_global*100)
        @printf("\t\tacc rate (global, overall): %.1f%%\n", a.acc_global/a.prop_global*100)
      end
      a.acc_rate = 0.0
      a.acc_rate_global = 0.0
      flush(STDOUT)
    end
    
    if now() >= p.walltimelimit
      println("Approaching wall-time limit. Safely exiting. (i = $(i)). Current date: $(Dates.format(now(), "d.u yyyy HH:MM")).")
      exit(42)
    end
  end

  nothing
end

function update(mc::DQMC, i::Int)
  const p = mc.p
  const s = mc.s
  const l = mc.l
  const a = mc.a

  propagate(mc)

  if p.global_updates && (s.current_slice == p.slices && s.direction == -1 && mod(i, p.global_rate) == 0)
    a.prop_global += 1
    @mytimeit a.to "global updates" b = global_update(mc)
    a.acc_rate_global += b
    a.acc_global += b
  end

  a.acc_rate += local_updates(mc)
  nothing
end



# -------------------------------------------------------
#                     Other stuff
# -------------------------------------------------------
# cosmetics
import Base.summary
import Base.show
Base.summary(mc::DQMC) = "DQMC"
function Base.show(io::IO, mc::DQMC{C}) where C<:Checkerboard
  print(io, "DQMC of O($(mc.p.opdim)) model\n")
  print(io, "r = ", mc.p.r, ", λ = ", mc.p.lambda, ", c = ", mc.p.c, ", u = ", mc.p.u, "\n")
  print(io, "Beta: ", mc.p.beta, " (T ≈ $(round(1/mc.p.beta, 3)))", "\n")
  print(io, "Checkerboard: ", C, "\n")
  print(io, "B-field: ", mc.p.Bfield)
end
Base.show(io::IO, m::MIME"text/plain", mc::DQMC) = print(io, mc)



"""
Calculate DateTime where wall-time limit will be reached.

Example call: wtl2DateTime("3-12:42:05", now())
"""
function wtl2DateTime(wts::AbstractString, start_time::DateTime)
  @assert contains(wts, "-")
  @assert contains(wts, ":")
  @assert length(wts) >= 10

  tmp = split(wts, "-")

  d = parse(Int, tmp[1])
  h, m, s = parse.(Int, split(tmp[2], ":"))

  start_time + Dates.Day(d) + Dates.Hour(h) + Dates.Minute(m) + Dates.Second(s)
end

function set_walltimelimit!(p, start_time)
  if "WALLTIMELIMIT" in keys(ENV)
    p.walltimelimit = wtl2DateTime(ENV["WALLTIMELIMIT"], start_time)
    @show ENV["WALLTIMELIMIT"]
  elseif contains(gethostname(), "jw")
    p.walltimelimit = wtl2DateTime("0-23:30:00", start_time) # JUWELS
    println("Set JUWELS walltime limit, i.e. 0-23:30:00.")
  end

  nothing
end


"""

    csheuristics(wctl, udsd, writeeverynth; maxcs=100)

Find a reasonable value for the chunk size `cs` based on wallclocktime limit (DateTime),
ud-sweep duration `udsd` (in seconds) and `writeeverynth` to avoid

* non-progressing loop of resubmitting the simulation because we never make it to a dump
* memory overflow (we use a maximum chunk size `maxcs`)
* slowdown of simulation by IO (for too small chunk size)

A value of 0 for `wctl` is interpreted as no wallclocktime limit and chunk size `maxcs` will be returned.
"""
function csheuristics(wctl::DateTime, udsd::Real, writeeverynth::Int; maxcs::Int=100)
    wcts = (wctl - now()).value / 1000. # seconds till we hit the wctl
    # wcts == 0.0 && (return maxcs) # no wallclocktime limit

    num_uds = wcts/(udsd * writeeverynth) # Float64: number of add!s we will (in theory) perform in the given time
    num_uds *= 0.92 # 8% buffer, i.e. things might take longer than expected.
    cs = max(floor(Int, min(num_uds, 100)), 1)
end


"""
Choose a apropriate chunk size for the given Monte Carlo simulation.
"""
function choose_chunk_size(mc::AbstractDQMC)
    const p = mc.p
    const to_udsweep = mc.a.to["udsweep"]

    udsd = TimerOutputs.time(to_udsweep) *10.0^(-9)/TimerOutputs.ncalls(to_udsweep)
    cs = csheuristics(p.walltimelimit, udsd, p.write_every_nth)
    cs = min(cs, floor(Int, p.measurements/p.write_every_nth)) # cs musn't be larger than # measurements
    p.edrun && (cs = 1000) # this should probably better set maxcs in csheuristics call

    secs_to_dump = cs * p.write_every_nth * udsd
    dump_date = now() + Millisecond(ceil(Int, secs_to_dump*1000))
    println("Chose a chunk size of $cs. Should dump to file around $(formatdate(dump_date)). Walltime limit is $(formatdate(p.walltimelimit)).")

    return cs
end


formatdate(d) = Dates.format(d, "d.u yyyy HH:MM")