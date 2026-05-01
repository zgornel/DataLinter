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
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tblref[])
        link_type = extract_capture_value(linting_ctx.parsing_data, "link_type")
        tc = getindex(tblref[], target_variable)
        nvars = length(unique(tc))
        if nvars == 2
            acceptable_link_values_strings = ["\"$v\"" for v in acceptable_link_values]
            if link_type ∈ acceptable_link_values || link_type in acceptable_link_values_strings
                return PassedCheck(nothing)
            else
                return FailedCheck(info = "link type is: link_type")
            end
        else  # nvars != 2
            return FailedCheck(info = "target has $nvars values")
        end
    catch e
        @debug "is_glmmTMB_data_correctly_modelled: Failed\n$e"
        return NotAvailableCheck(info = string(e))
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
            return NotAvailableCheck(info = "unknown algorithm '$alg'")
        end
        check = true
        if check_predictors
            for pv in predictor_variables
                _vals = getindex(tblref[], process_column_for_indexing(pv))
                if !isempty(symdiff([0.0, 1], unique(_vals)))  # skip one-hot encoded vars
                    check &= is_normally_distributed(_vals, pvalue_threshold)
                end
            end
        end
        if check_target
            tc = getindex(tblref[], target_variable)
            check &= is_normally_distributed(tc, pvalue_threshold)
        end
        return check ? PassedCheck(info = alg) : FailedCheck(info = alg)
    catch e
        @debug "is_data_normally_distributed: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end

is_data_normally_distributed(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)


function is_glm_data_correctly_modelled(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        pvalue_threshold = PVALUE_THRESHOLD
    )
    try
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tblref[])
        family = extract_capture_value(linting_ctx.parsing_data, "family")
        check = true
        for pv in predictor_variables
            _vals = getindex(tblref[], process_column_for_indexing(pv))
            if !isempty(symdiff([0.0, 1], unique(_vals)))  # skip one-hot encoded vars
                check &= is_normally_distributed(_vals, pvalue_threshold)
            end
        end
        if family == "\"binomial\"" || family == "binomial"
            tc = getindex(tblref[], target_variable)
            check &= length(unique(tc)) == 2
        end
        return check ? PassedCheck(nothing) : FailedCheck(nothing)
    catch e
        @debug "is_glm_data_correctly_modelled: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end

is_glm_data_correctly_modelled(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

const PAIRWISE_COLINEARITY_THRESHOLD = 0.9

"""
    check_pairwise_colinearity(v1, v2; threshold=0.9)

Check if two numeric vectors have high pairwise correlation (colinearity).
Returns false if correlation exceeds threshold, true otherwise.
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
        return corr < threshold
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

        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tblref[])
        tc = getindex(tblref[], target_variable)
        alg = extract_capture_value(linting_ctx.parsing_data, "algorithm")
        if alg ∉ algorithms
            return NotAvailableCheck(info = "unknown algorithm '$alg'")
        end
        check = true
        colinears = Symbol[]
        for pv in predictor_variables
            _vals = getindex(tblref[], process_column_for_indexing(pv))
            _corr = check_pairwise_colinearity(tc, _vals; threshold)
            if !isnothing(_corr)
                check &= _corr
                !_corr && push!(colinears, pv)
            end
        end
        return check ? PassedCheck(info = alg) : FailedCheck(info = (colinears = colinears, alg = alg))
    catch e
        @debug "check_colinearity_with_target: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end


const R_BASELINE_LINTERS = [
    # Imbalanced target variable in data (R code version)
    (
        name = :R_imbalanced_target_variable,
        description = """Tests that target variable values are balanced (no class less than θ%)""",
        f = is_imbalanced_target_variable,
        failure_message = (name, args...) -> "Imbalanced distribution of target variable values",
        correct_message = (name, args...) -> "Target variable values are balanced",
        warn_level = "warning",
        query = "{{::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Binary target data modelled by binomial family modelling with correct link type
    (
        name = :R_glmmTMB_binomial_modelling,
        description = """ Ensures that binary varianles are modelled with correct family and link values""",
        f = is_glmmTMB_data_correctly_modelled,
        failure_message = (name, args...) -> "Incorrect binomial data modelling (glmmTMB)",
        correct_message = (name, args...) -> "Correct binomial data modelling (glmmTMB)",
        warn_level = "warning",
        query = "glmmTMB({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, family=binomial(link={{link_type::IDENTIFIER}}))",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Corectness test for linear modelling
    (
        name = :R_data_normally_distributed,
        description = """ Tests that variables are normally distributed""",
        f = is_data_normally_distributed,
        failure_message = (name, result) -> "Non-normal variables present ($(result.info))",
        correct_message = (name, result) -> "Variables are normally distributed ($(result.info))",
        warn_level = "info",
        query = "{{algorithm::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Binary target data modelled by binomial family modelling
    (
        name = :R_glm_binomial_modelling,
        description = """ Ensures that binary variables are modelled by 'glm' with correct data values""",
        f = is_glm_data_correctly_modelled,
        failure_message = (name, args...) -> "Incorrect binomial data modelling (glm): non-normal predictors or target with more than 2 values",
        correct_message = (name, args...) -> "Correct binomial data modelling (glm)",
        warn_level = "warning",
        query = "glm({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, family={{family::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Check colinearity between target variable and predictor variables for specific algorithms
    (
        name = :R_colinearity_with_target,
        description = """ Checks colinearities between target variable and its target variables""",
        f = check_colinearity_with_target,
        failure_message = (name, result) -> "Found highly colinear variables with target ($(result.info.alg)): $(result.info.colinears)",
        correct_message = (name, result) -> "No colinearities between target and predictor variables ($(result.info.alg))",
        warn_level = "important",
        query = "{{algorithm::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),
]
