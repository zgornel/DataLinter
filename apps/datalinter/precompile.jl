using datalinter
using DataLinter

TEST_PATH = abspath(joinpath(dirname(@__FILE__), "..", "..", "test"))
configpath = joinpath(TEST_PATH, "test_config.toml")
DATA_PATHS = [
    joinpath(TEST_PATH, "data", "correlated_data.arrow"),
    joinpath(TEST_PATH, "data", "correlated_data.parquet"),
    joinpath(TEST_PATH, "data", "correlated_data.csv"),
]
CODE_PATHS = [
    joinpath(TEST_PATH, "code", "r_snippet_binomial.r"),
]
OPTIONS = [
    (:output_type => :text, :show_stats => true, :show_na => true, :pretty_print => true, :progress => false, :linters => ["all"]),
    (:output_type => :text, :show_stats => false, :show_na => false, :pretty_print => false, :progress => false, :linters => ["all"]),
    (:output_type => :json, :show_stats => true, :show_na => true, :pretty_print => true, :progress => false, :linters => ["all"]),
    (:output_type => :json, :show_stats => false, :show_na => false, :pretty_print => false, :progress => false, :linters => ["all"]),
    (:output_type => :html, :show_stats => true, :show_na => true, :pretty_print => true, :progress => false, :linters => ["all"]),
    (:output_type => :html, :show_stats => false, :show_na => false, :pretty_print => false, :progress => false, :linters => ["all"]),
]
kbpath = ""
for filepath in DATA_PATHS
    for codepath in CODE_PATHS
        for opts in OPTIONS
            buffer = IOBuffer()
            DataLinter.cli_linting_workflow(filepath, codepath, kbpath, configpath; buffer, opts...)
        end
    end
end
