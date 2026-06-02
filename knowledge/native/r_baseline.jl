has_only_these_values(thesevalues) = valstocheck -> isempty(symdiff(thesevalues, unique(valstocheck)))

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
    try
        return string(getproperty(ParSitter.get_capture(query_results, capture_symbol), :v))
    catch
        throw(ErrorException("'extract_capture_value': Could not find '$capture_symbol' in query results"))
    end
end

function process_for_printing(iterable; joinchar = ", ", maxlen = 50)
    output = join(string.(iterable), joinchar)
    if length(output) > maxlen
        output = output[1:maxlen] * "..."
    end
    return output
end

function is_glmmTMB_data_correctly_modelled(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
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
                return PassedCheck()
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
        tblref::Base.RefValue{<:Tables.AbstractColumns},
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
                if !has_only_these_values([0.0, 1.0])(_vals)
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

is_data_normally_distributed(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck()


function is_glm_data_correctly_modelled(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
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
            if !has_only_these_values([0.0, 1.0])(_vals)
                check &= is_normally_distributed(_vals, pvalue_threshold)
            end
        end
        if family == "\"binomial\"" || family == "binomial"
            tc = getindex(tblref[], target_variable)
            check &= length(unique(tc)) == 2
        end
        return check ? PassedCheck() : FailedCheck()
    catch e
        @debug "is_glm_data_correctly_modelled: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end

is_glm_data_correctly_modelled(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck()

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
        tblref::Base.RefValue{<:Tables.AbstractColumns},
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
        return check ? PassedCheck(info = (colinears = colinears, alg = alg)) : FailedCheck(info = (colinears = colinears, alg = alg))
    catch e
        @debug "check_colinearity_with_target: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end


const SAMPLE_SIZE_ALGORITHMS = ["lm", "glm", "glmmTMB"]
const EPV_THRESHOLD = 10

function check_sample_size_adequacy(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        epv_threshold = EPV_THRESHOLD,
        algorithms = SAMPLE_SIZE_ALGORITHMS
    )
    try
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tblref[])
        tc = getindex(tblref[], target_variable)
        alg = extract_capture_value(linting_ctx.parsing_data, "algorithm")
        n_rows = Tables.rowcount(tblref[])
        n_predictors = length(predictor_variables)
        n_per_predictor = n_rows / n_predictors
        if alg ∈ algorithms
            if has_only_these_values([0.0, 1.0])(tc) # Binomial case
                n_events = min(sum(tc .== 1.0), sum(tc .== 0.0))
                epv = n_events / n_predictors
                if epv > epv_threshold
                    return PassedCheck(info = "EPV=$(repr(epv, context = :compact => true)), higher than $epv_threshold")
                else
                    return FailedCheck(info = "EPV=$(repr(epv, context = :compact => true)), lower than $epv_threshold")
                end
            else  # linear case
                min_n_liberal = 50 + 8 * n_predictors  # Green 1991
                min_n_conservative = 104 + n_predictors # Green 1991
                pass_rule_of_thumb = n_rows >= min_n_liberal && n_rows >= min_n_conservative
                if pass_rule_of_thumb
                    return PassedCheck(info = "$n_rows samples pass [Green, 1991] rule of thumb")
                else
                    return FailedCheck(info = "$n_rows samples did not pass [Green, 1991] rule of thumb")
                end
            end
        else
            return NotAvailableCheck(info = "unknown algorithm '$alg'")
        end
    catch e
        @debug "check_sample_size_adequacy: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end

function check_variables_present_in_data(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        kwargs...
    )
    try
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tblref[])
        missing_vars = []
        data_columns = Tables.columnnames(tblref[])
        for v in process_column_for_indexing.([target_variable, predictor_variables...])
            if v ∉ data_columns
                push!(missing_vars, v)
            end
        end
        if isempty(missing_vars)
            return PassedCheck()
        else
            return FailedCheck(info = process_for_printing(missing_vars))
        end
    catch e
        @debug "check_variables_present_in_data: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end

const DEFAULT_NP_LEVEL_RATIO = 10
function check_high_cardinality_categoricals(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        n_p_level_ratio = DEFAULT_NP_LEVEL_RATIO
    )
    try
        tbl = tblref[]
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tbl)
        n_rows = Tables.rowcount(tbl)
        high_cardinalities = []
        for pv in process_column_for_indexing.(predictor_variables)
            for categorical_type in [Integer, AbstractString, Symbol]
                if Tables.columntype(tbl, pv) <: categorical_type
                    _vals = getindex(tbl, pv)
                    if n_rows / length(unique(_vals)) < n_p_level_ratio
                        push!(high_cardinalities, pv)
                    end
                end
            end
        end
        if isempty(high_cardinalities)
            return PassedCheck()
        else
            return FailedCheck(info = process_for_printing(high_cardinalities))
        end
    catch e
        @debug "check_high_cardinality_categoricals: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end

const DEFAULT_NUMERIC_SCALE_THRESHOLD = 100
function check_numeric_scale_imbalance(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        numeric_scale_threshold = DEFAULT_NUMERIC_SCALE_THRESHOLD
    )
    try
        tbl = tblref[]
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tbl)
        scales = Dict()
        for pv in process_column_for_indexing.(predictor_variables)
            if Tables.columntype(tbl, pv) <: AbstractFloat || Tables.columntype(tbl, pv) <: Real
                _vals = getindex(tbl, pv)
                push!(scales, pv => float(abs(maximum(_vals) - minimum(_vals))))
            end
        end
        if isempty(scales)
            return PassedCheck()
        end
        min_scale = minimum(values(scales))
        high_scales = [k for (k, v) in scales if v / min_scale > numeric_scale_threshold]
        if isempty(high_scales)
            return PassedCheck()
        else
            return FailedCheck(info = process_for_printing(high_scales))
        end
    catch e
        @debug "check_numeric_scale_imbalance: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end


const NEAR_ZERO_VARIANCE_ALGORITHMS = ["lm", "glm", "glmmTMB"]
const DEFAULT_NZ_VARIANCE_THRESHOLD = 100
function check_near_zero_variance_predictors(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        algorithms = NEAR_ZERO_VARIANCE_ALGORITHMS,
        variance_threshold = DEFAULT_NZ_VARIANCE_THRESHOLD
    )
    try
        tbl = tblref[]
        rhs = extract_capture_value(linting_ctx.parsing_data, "predictor_variables")
        target_variable, predictor_variables = process_formula_variables(linting_ctx.target_variable, rhs, tbl)
        alg = extract_capture_value(linting_ctx.parsing_data, "algorithm")
        if alg ∉ algorithms
            return NotAvailableCheck(info = "unknown algorithm '$alg'")
        end
        nz_variances = Dict()
        for pv in process_column_for_indexing.(predictor_variables)
            try
                _vals = getindex(tbl, pv)
                nvar = std(_vals)^2 / abs(mean(_vals))
                if nvar < variance_threshold
                    push!(nz_variances, pv => float(nvar))
                end
            catch
                # do nothing if fails
            end
        end
        if isempty(nz_variances)
            return PassedCheck()
        else
            return FailedCheck(info = process_for_printing(nz_variances))
        end
    catch e
        @debug "check_near_zero_variance_predictors: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end


const R_BASELINE_LINTERS = [
    # Imbalanced target variable in data (R code version)
    (
        name = :R_imbalanced_target_variable,
        description = """Tests that target variable values are balanced (no class less than θ%)""",
        f = is_imbalanced_target_variable,
        failure_message = (name, result) -> "Imbalanced target column in '$name' for value(s): $(process_for_printing(result.info))",
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
        failure_message = (name, result) -> "Found highly colinear variables with target ($(result.info.alg)): $(process_for_printing(result.info.colinears))",
        correct_message = (name, result) -> "No colinearities between target and predictor variables ($(result.info.alg))",
        warn_level = "important",
        query = "{{algorithm::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Checks that the number of observations and predictors have stable ratios
    (
        name = :R_sample_size_adequacy,
        description = """Checks that the number of observations and predictors have stable ratios""",
        f = check_sample_size_adequacy,
        failure_message = (name, result) -> "Sample size and power check failed: $(result.info)",
        correct_message = (name, result) -> "Sample size and power check OK: $(result.info)",
        warn_level = "warning",
        query = "{{algorithm::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Checks that variables present in the formula are also present in the data as columns
    (
        name = :R_variables_present_in_data,
        description = """Checks that the formula variables are present in the data""",
        f = check_variables_present_in_data,
        failure_message = (name, result) -> "Found formula variables not present in data: $(result.info)",
        correct_message = (name, args...) -> "All formula variables present in data",
        warn_level = "important",
        query = "{{::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Checks for categorical predictors with too many unique levels relative to sample size
    (
        name = :R_high_cardinality_categoricals,
        description = """Checks for categorical predictors with too many unique levels relative to sample size""",
        f = check_high_cardinality_categoricals,
        failure_message = (name, result) -> "Found categorical predictors with too many unique levels: $(result.info)",
        correct_message = (name, args...) -> "Found no categorical predictors with too many unique levels",
        warn_level = "warning",
        query = "{{::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Detects numeric predictors with vastly different magnitudes/scales
    (
        name = :R_numeric_scale_imbalance,
        description = """Detects numeric predictors with vastly different magnitudes/scales""",
        f = check_numeric_scale_imbalance,
        failure_message = (name, result) -> "Found numerical predictors with magnitude/scale imbalance: $(result.info)",
        correct_message = (name, args...) -> "No numerical predictors with magnitude/scale imbalance found",
        warn_level = "warning",
        query = "{{::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Flags numeric predictors with near-zero variance values (using relative variance thresholds)
    (
        name = :R_near_zero_variance_predictors,
        description = """Flags numeric predictors with near-zero variance values (using relative variance thresholds)""",
        f = check_near_zero_variance_predictors,
        failure_message = (name, result) -> "Found numerical predictors with near-zero variance: $(result.info)",
        correct_message = (name, args...) -> "No numerical predictors with near-zero variance found",
        warn_level = "warning",
        query = "{{algorithm::IDENTIFIER}}({{target_variable::IDENTIFIER}}~{{predictor_variables::IDENTIFIER}}, {{::IDENTIFIER}}={{::IDENTIFIER}})",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Code-only dummy linter
    (
        name = :R_code_only_dummy_linter,
        description = """Dummy linter""",
        f = (args...; kwargs...)-> PassedCheck(),
        failure_message = (name, result) -> "This never fails",
        correct_message = (name, args...) -> "Dummy check passed",
        warn_level = "experimental",
        query = "{{::IDENTIFIER}}",
        query_match_type = :speculative,
        programming_language = "r",
        requirements = Dict("iterable_type" => :code_only, "linting_ctx" => true),
    ),
]
