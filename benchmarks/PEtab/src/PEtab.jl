module PEtab

using Downloads
using SHA
using YAML

function check_benchmark(dir, benchmarkname, hash)
    temp_file = joinpath(dir, "temp.txt")

    for file in readdir(dir)
        open(temp_file, "a") do f
            write(f, read(joinpath(dir, file)))
        end
    end

    cksum = bytes2hex(open(io->sha256(io), temp_file))
    rm(temp_file)
    if cksum != hash
        @warn "The downloaded test benchmarkname `$benchmarkname' has probably been modified in https://github.com/Benchmarking-Initiative/Benchmark-Models-PEtab. New hash is $cksum."
    end
    nothing
end

function download_benchmark(dir, benchmarkname, hash)
    url = "https://raw.githubusercontent.com/Benchmarking-Initiative/Benchmark-Models-PEtab/master/Benchmark-Models/$(benchmarkname)"

    mkpath(dir)
    Downloads.download(url * "/" * "$(benchmarkname).yaml", joinpath(dir, "$(benchmarkname).yaml"))
    petab_yaml = YAML.load_file(joinpath(dir, "$(benchmarkname).yaml"))
    filenames = [petab_yaml["parameter_file"]]
    for item in keys(only(petab_yaml["problems"]))  # We don't support multiple problems, condition_files etc. yet.
        push!(filenames, only(only(petab_yaml["problems"])[item]))
    end
    # filenames = [
    #     "$(benchmarkname).yaml",
    #     "experimentalCondition_$(benchmarkname).tsv",
    #     "measurementData_$(benchmarkname).tsv",
    #     "model_$(benchmarkname).xml",
    #     "observables_$(benchmarkname).tsv",
    #     "parameters_$(benchmarkname).tsv",
    #     "simulatedData_$(benchmarkname).tsv",
    #     "visualizationSpecification_$(benchmarkname).tsv"]

    for name in filenames
        try
            Downloads.download(url * "/" * name, joinpath(dir, name))
        catch e
            println("Could not download $benchmarkname from $url")
        end
    end
    check_benchmark(dir, benchmarkname, hash)
    nothing
end

export download_benchmark

end  # module