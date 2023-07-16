using CSV
using DataFrames
using DifferentialEquations
using ModelingToolkit  # Todo: needed in JuliaSimModelOptimizer._get_module

using Optim
using Optimization
using OptimizationBBO
using OptimizationMultistartOptimization
using OptimizationPolyalgorithms

using PEtab
using PumasQSP

outfile = joinpath(@__DIR__, "results.csv")
benchmarks = [
    # ("Alkan_SciSignal2018", "hash123", :auto),  # Requires SBML piecewise fix.
    # ("Bachmann_MSB2011", "hash123", :auto)  # multiple different observableParameter overrides not supported
    ("Beer_MolBioSystems2014", "hash123", :auto)
    
]

n_starts = 2  # 100

methods = [SingleShooting(maxiters = 1, maxtime = 1,
                          optimizer=BBO_adaptive_de_rand_1_bin_radiuslimited()),
        #    SingleShooting(maxiters = 1, maxtime = 1,
        #                   optimizer=Optim.LBFGS()),
        #    SingleShooting(maxiters = 1, maxtime = 1,
        #                   optimizer=MultistartOptimization.TikTak(n_starts),
        #                   local_method=Optim.LBFGS()),
        #    SingleShooting(maxiters = 1, maxtime = 1,
        #                   optimizer=PolyOpt()),

        #    MultipleShooting(maxiters = 1, maxtime = 1, trajectories=2,
        #                   optimizer=BBO_adaptive_de_rand_1_bin_radiuslimited()),
        #    MultipleShooting(maxiters = 1, maxtime = 1, trajectories=4,
        #                   optimizer=BBO_adaptive_de_rand_1_bin_radiuslimited()),
        #    MultipleShooting(maxiters = 1, maxtime = 1, trajectories=8,
        #                   optimizer=BBO_adaptive_de_rand_1_bin_radiuslimited())
        ]

cases = [Base.product(benchmarks, methods)...]

res_df = DataFrame("transcription_method" => String[],
                   "algorithm" => String[],
                   "benchmark" => String[],
                   "fval" => Float64[],
                   "elapsed" => Float64[])
for case in cases
    bm, method = case

    benchmarkname, hash, odesolver = bm

    transcription_method = summary(method)
    alg = PumasQSP.JuliaSimModelOptimizer.get_optimizer(method)
    algname = string(nameof(typeof(alg)))

    tempdir = mktempdir()
    download_benchmark(tempdir, benchmarkname, hash)
    yaml_fn = joinpath(tempdir, "$(benchmarkname).yaml")
    invprob = import_petab(yaml_fn)
    invprob = remake_trials(invprob, alg=odesolver)
    
    res = calibrate(invprob, method)
    methodstring = "$(transcription_method)_$(algname)"
    @info "Solved $benchmarkname with $methodstring:\n    fval: $(res.loss_history[end])\n    elapsed: $(res.elapsed)"

    push!(res_df, (transcription_method, algname, benchmarkname, res.loss_history[end], res.elapsed))
    CSV.write(outfile, res_df)
end
