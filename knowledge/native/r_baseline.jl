const ACCEPTABLE_LINK_VALUES = ["logit", "probit", "log-log", "cloglog", "cauchit"]

# Returns target and predictor variables from a R formula
function process_formula_variables(target_variable, rhs, tbl)
    # Extract target variable
    target_variable_symbol(tbl, tv::Int) = Tables.columnnames(tbl)[tv]
    target_variable_symbol(tbl, tv::Symbol) = tv
    target_variable_symbol(tbl, tv::String) = Symbol(tv)
    _target_variable = target_variable_symbol(tbl, target_variable)
    # Extract predictor variables
    rhs_symbols = Symbol.(RFormulaParser.extract_identifiers(rhs))
    predictor_variables = setdiff(rhs_symbols, [_target_variable])
    # Handle "."
    if length(predictor_variables) == 1 && first(predictor_variables) == :.
        predictor_variables = setdiff(Tables.columnnames(tbl), [_target_variable])
    end
    return _target_variable::Symbol, predictor_variables::Vector{Symbol}
end

# Extract the value of a captured symbol from query results (single match),
# of the form: (match::Bool, captured::MultiDict, node::EzXML.Node)
function extract_capture_value(query_results, capture_symbol)
    return string(getproperty(ParSitter.get_capture(query_results, capture_symbol), :v))
end


function is_glmmTMB_data_correctly_modelled(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        acceptable_link_values = ACCEPTABLE_LINK_VALUES
    )
    try
        col = linting_ctx.target_variable
        query_results = linting_ctx.parsing_data
        tc = getindex(tblref[], __process_target_col(col))
        nvars = length(unique(tc))
        arg_name, _... = ParSitter.get_capture(query_results, "arg_name")
        arg_value, _... = ParSitter.get_capture(query_results, "arg_value")
        if nvars == 2
            if arg_name == "link"
                return arg_value ∈ acceptable_link_values
            else
                return true
            end
        else  # nvars != 2
            return false
        end
    catch e
        @debug "is_glmmTMB_data_correctly_modelled: Failed\n$e"
        return nothing
    end
end

is_glmmTMB_data_correctly_modelled(::Type{<:ListEltype}, args...; kwargs...) = nothing

const PVALUE_THRESHOLD = 0.2

function is_normally_distributed(ux::AbstractVector, pvalue_threshold = PVALUE_THRESHOLD)
    x = (ux .- mean(ux)) ./ std(ux)
    p1 = pvalue(ExactOneSampleKSTest(x, Distributions.Normal(0, 1.0)), tail = :both)
    p2 = pvalue(ShapiroWilkTest(x))
    return p1 >= pvalue_threshold || p2 >= pvalue_threshold
end

const NORMALITY_CHECK_ALGORITHMS = ["lm", "glm", "glmmTMB"]

function is_data_normally_distributed(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        pvalue_threshold = PVALUE_THRESHOLD,
        algorithms = NORMALITY_CHECK_ALGORITHMS,
        check_target = false,
        check_predictors = true
    )
    try
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tblref[])
        alg = extract_capture_value(linting_ctx.parsing_data, "algorithm")
        if alg ∉ algorithms
            return nothing
        end
        result = true
        if check_predictors
            for pv in predictor_variables
                _vals = getindex(tblref[], __process_target_col(pv))
                if !isempty(symdiff([0.0, 1], unique(_vals)))  # skip one-hot encoded vars
                    @info "\t ->$pv: $(is_normally_distributed(_vals, pvalue_threshold))"
                    result &= is_normally_distributed(_vals, pvalue_threshold)
                end
            end
        end
        if check_target
            tc = getindex(tblref[], target_variable)
            result &= is_normally_distributed(tc, pvalue_threshold)
        end
        return result
    catch e
        @debug "is_data_normally_distributed: Failed\n$e"
        return nothing
    end
end

is_data_normally_distributed(::Type{<:ListEltype}, args...; kwargs...) = nothing


function is_glm_data_correctly_modelled(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        pvalue_threshold = PVALUE_THRESHOLD
    )
    try
        col = linting_ctx.target_variable
        query_results = linting_ctx.parsing_data
        tc = getindex(tblref[], __process_target_col(col))
        pvars_str, _... = ParSitter.get_capture(linting_ctx.parsing_data, "predictor_variables")
        #TODO: Add '.' processing
        pvars = RFormulaParser.extract_identifiers(pvars_str)
        result = true
        for pvar in pvars
            _vals = getindex(tblref[], __process_target_col(pvar))
            if !isempty(symdiff([0.0, 1], unique(_vals)))  # skip one-hot encoded vars
                result &= is_normally_distributed(_vals, pvalue_threshold)
            end
        end
        return result && length(unique(tc)) == 2
    catch e
        @debug "is_glm_data_correctly_modelled: Failed\n$e"
        return nothing
    end
end

is_glm_data_correctly_modelled(::Type{<:ListEltype}, args...; kwargs...) = nothing

const PAIRWISE_COLINEARITY_THRESHOLD = 0.9

"""
    check_pairwise_colinearity(v1, v2; threshold=0.9)

Check if two numeric vectors have high pairwise correlation (colinearity).
Returns true if correlation exceeds threshold, false otherwise.
Handles missing values by filtering them out.
"""
function check_pairwise_colinearity(v1, v2; threshold = PAIRWISE_COLINEARITY_THRESHOLD)
    # Filter out missing values
    mask = .!ismissing.(v1) .& .!ismissing.(v2)
    if sum(mask) < 3  # Need at least 3 points for meaningful correlation
        return nothing
    end
    v1_clean = v1[mask]
    v2_clean = v2[mask]
    # Calculate Pearson correlation coefficient
    try
        corr = abs(cor(v1_clean, v2_clean))
        return corr >= threshold
    catch
        return nothing
    end
end

const PAIRWISE_COLINEARITY_ALGORITHMS = ["lm", "glm", "glmmTMB"]

function check_colinearity_with_target(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        threshold = PAIRWISE_COLINEARITY_THRESHOLD,
        algorithms = PAIRWISE_COLINEARITY_ALGORITHMS
    )
    try
        col = linting_ctx.target_variable
        query_results = linting_ctx.parsing_data
        tc = getindex(tblref[], __process_target_col(col))
        alg, _... = ParSitter.get_capture(linting_ctx.parsing_data, "algorithm")
        if alg ∉ algorithms
            return nothing
        end
        pvars_str, _... = ParSitter.get_capture(linting_ctx.parsing_data, "predictor_variables")
        pvars = RFormulaParser.extract_identifiers(pvars_str)
        result = false
        for pvar in pvars
            _vals = getindex(tblref[], __process_target_col(pvar))
            _corr = check_pairwise_colinearity(tc, _vals; threshold)
            if !isnothing(_corr)
                result |= _corr
            end
        end
        return result
    catch e
        @debug "check_colinearity_with_target: Failed\n$e"
        return nothing
    end
end


const R_BASELINE_LINTERS = [
    # Imbalanced target variable in data (R code, glmmTMB algorithm)
    (
        name = :R_glmmTMB_target_variable,
        description = """ Tests that data labels are balanced (no class less than θ%)""",
        f = is_imbalanced_target_variable,
        failure_message = name -> "Imbalanced target variable (glmmTMB)",
        correct_message = name -> "Target variable is balanced (glmmTMB)",
        warn_level = "warning",
        correct_if = check_correctness(false),
        query = (
            "*",
            "glmmTMB",                      # -> glmmTMB
            (
                "*",                          # -> (arguments...)
                (
                    "*",
                    (
                        "*",
                        "@target_variable",
                        (
                            "@predictor_variables",
                            "*",
                        ),
                    ),
                ),
            ),
        ),
        query_match_type = :strict,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Binary target data modelled by binomial family modelling with correct link type
    (
        name = :R_glmmTMB_binomial_modelling,
        description = """ Ensures that binary varianles are modelled with correct family and link values""",
        f = is_glmmTMB_data_correctly_modelled,
        failure_message = name -> "Incorrect binomial data modelling (glmmTMB)",
        correct_message = name -> "Correct binomial data modelling (glmmTMB)",
        warn_level = "warning",
        correct_if = check_correctness(true),
        query = (
            "*",
            "glmmTMB",                      # -> glmmTMB
            (
                "*",                          # -> (arguments...)
                (
                    "*",                       # -> argument
                    (
                        "*",                    # -> binary_operator
                        "@target_variable",
                        (
                            "@predictor_variables",
                            "*",
                        ),
                    ),
                ),
                (
                    "*",                       # -> family = binomial(link=...)
                    "family",                # -> family
                    (
                        "*",                    # -> binomial(link=...)
                        "binomial",           # -> binomial
                        (
                            "*",                 # -> argument
                            (
                                "*",
                                "@arg_name",
                                (
                                    "*",
                                    "@arg_value",
                                ),
                            ),
                        ),
                    ),
                ),
            ),
        ),
        query_match_type = :nonstrict,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Corectness test for linear modelling
    (
        name = :R_data_normally_distributed,
        description = """ Tests that variables are normally distributed""",
        f = is_data_normally_distributed,
        failure_message = name -> "Non-normal variables present",
        correct_message = name -> "Variables are normally distributed",
        warn_level = "info",
        correct_if = check_correctness(true),
        query = "{{algorithm::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Binary target data modelled by binomial family modelling
    (
        name = :R_glm_binomial_modelling,
        description = """ Ensures that binary variables are modelled with correct data values""",
        f = is_glm_data_correctly_modelled,
        failure_message = name -> "Incorrect binomial data modelling (glm), non-normal variables present",
        correct_message = name -> "Correct binomial data modelling (glm)",
        warn_level = "warning",
        correct_if = check_correctness(true),
        query = (
            "*",
            "glm",                            # -> glmmTMB
            (
                "*",                          # -> (arguments...)
                (
                    "*",                       # -> argument
                    (
                        "*",                    # -> binary_operator
                        "@target_variable",
                        (
                            "@predictor_variables",
                            "*",
                        ),
                    ),
                ),
                (
                    "*",                      # -> family = "binomial"
                    "family",                 # -> family
                    (
                        "\"binomial\"",           # -> binomial
                    ),
                ),
            ),
        ),
        query_match_type = :nonstrict,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Check colinearity between target variable and predictor variables for specific algorithms
    (
        name = :R_colinearity_with_target,
        description = """ Checks colinearities between target variable and its target variables""",
        f = check_colinearity_with_target,
        failure_message = name -> "At least one predictor variable is highly colinear with target variable",
        correct_message = name -> "No colinearities between target and predictor variables",
        warn_level = "important",
        correct_if = check_correctness(false),
        query = "{{algorithm::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),
]
