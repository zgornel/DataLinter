using Dates
using Random
using CSV
using Tables

#TODO: Improve performance when using scripts:
# https://timholy.github.io/SnoopCompile.jl/stable/tutorials/invalidations/

using PrecompileTools: @setup_workload, @compile_workload
@setup_workload begin
    @compile_workload begin
        using CSV
        using Tables
        using StatsBase

        TEST_PATH = abspath(joinpath(dirname(@__FILE__)), "..", "test")
        DATA_PATHS = [
            joinpath(TEST_PATH, "data", "correlated_data.arrow"),
            joinpath(TEST_PATH, "data", "correlated_data.parquet"),
            joinpath(TEST_PATH, "data", "correlated_data.csv")
        ]
        CODE_PATHS = [
            joinpath(TEST_PATH, "code", "r_snippet_binomial.r"),
        ]
        OPTIONS = [
            (:output_type=>:text, :show_stats=>true, :show_na=>true, :pretty_print=>true, :progress=>false, :linters=>["all"]),
            (:output_type=>:text, :show_stats=>false, :show_na=>false, :pretty_print=>false, :progress=>false, :linters=>["all"]),
            (:output_type=>:json, :show_stats=>true, :show_na=>true, :pretty_print=>true, :progress=>false, :linters=>["all"]),
            (:output_type=>:json, :show_stats=>false, :show_na=>false, :pretty_print=>false, :progress=>false, :linters=>["all"]),
            (:output_type=>:html, :show_stats=>true, :show_na=>true, :pretty_print=>true, :progress=>false, :linters=>["all"]),
            (:output_type=>:html, :show_stats=>false, :show_na=>false, :pretty_print=>false, :progress=>false, :linters=>["all"]),
        ]
        kbpath = ""
        configpath = joinpath(TEST_PATH, "test_config.toml")

        for filepath in DATA_PATHS
            for codepath in CODE_PATHS
                for opts in OPTIONS
                    buffer = IOBuffer()
                    cli_linting_workflow(filepath, codepath, kbpath, configpath; buffer, opts...)
                end
            end
        end
    end
end
