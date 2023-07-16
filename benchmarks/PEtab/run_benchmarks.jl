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
    ("Beer_MolBioSystems2014", "hash123", :auto),
    # ("Bertozzi_PNAS2020", "hash123", :auto),
    # # ("Blasi_CellSystems2016", "hash123", :auto),  # Postequlibration not yet supported
    # ("Boehm_JProteomeRes2014", "hash123", :auto),
    # ("Borghans_BiophysChem1997", "hash123", :auto),
    # # ("Brannmark_JBC2010", "hash123", :auto),  # Preequilibration not yet supported
    # ("Bruno_JExpBot2016", "hash123", :auto),
    # ("Chen_MSB2009", "hash123", :auto),
    # ("Crauste_CellSystems2017", "hash123", :auto),
    # ("Elowitz_Nature2000", "hash123", :auto),
    # ("Fiedler_BMC2016", "hash123", :auto),
    # # ("Froehlich_CellSystems2018", "hash123", :auto),  # Postequilibration not yet supported
    # ("Fujita_SciSignal2010", "hash123", :auto),
    # ("Giordano_Nature2020", "hash123", :auto),
    # # ("Isensee_JCB2018", "hash123", :auto),  # Preequilibration not yet supported
    # ("Laske_PLOSComputBiol2019", "hash123", :auto),
    # ("Lucarelli_CellSystems2018", "hash123", :auto),
    # ("Okuonghae_ChaosSolitonsFractals2020", "hash123", :auto),
    # ("Oliveira_NatCommun2021", "hash123", :auto),
    # ("Perelson_Science1996", "hash123", :auto),
    
    
    ("Rahman_MBS2016", "hash123", :auto),
    
    
    # # ("Raimundez_PCB2020", "hash123", :auto),  # Preequilibration not yet supported
    # ("SalazarCavazos_MBoC2020", "hash123", :auto),
    # ("Schwen_PONE2014", "hash123", :auto),
    # # ("Smith_BMCSystBiol2013", "hash123", :auto),  # Events not safely supported yet: https://github.com/SciML/ModelingToolkit.jl/issues/1715
    # ("Sneyd_PNAS2002", "hash123", :auto),
    # # ("Weber_BMC2015", "hash123", :auto),  # Preequilibration not yet supported
    # ("Zhao_QuantBiol2020", "hash123", :auto),
    # # ("Zheng_PNAS2012", "hash123", :auto)  # Preequilibration not yet supported
]

n_starts = 2  # 100

methods = [
             SingleShooting(maxiters = 1, maxtime = 1,
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
    # try
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
    # catch e
    #     @info "Failed to solve $benchmarkname due to $e"
    # end
end
