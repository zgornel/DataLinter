const PYTHON_BASELINE_LINTERS = [
    # Imbalanced target variable in data (Python code version)
    #
    # The query matches calls of the form `object.fit(X, y)` (as used throughout
    # the scikit-learn API), capturing the object the model is fit on (`object`)
    # and the data passed as the target/label argument (`target_variable`).
    # The actual balance check reuses `is_imbalanced_target_variable`, the same
    # generic function used by the R baseline (see `R_imbalanced_target_variable`
    # in `r_baseline.jl`); only the code query used to populate the
    # `LintingContext` differs between languages.
    (
        name = :Python_imbalanced_target_variable,
        description = """Tests that target variable values are balanced (no class less than θ%)""",
        f = is_imbalanced_target_variable,
        failure_message = (name, result) -> "Imbalanced target column in '$name' for value(s) $(process_for_printing(result.info))",
        correct_message = (name, args...) -> "Target variable values are balanced",
        warn_level = "warning",
        query = "{{object::IDENTIFIER}}.fit({{::IDENTIFIER}}, {{target_variable::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "python",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),
]
