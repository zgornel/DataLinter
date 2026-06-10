const MISSING_VALUES_THRESHOLD = 0.9
function has_many_missing_values(::T, v, vm, name, args...; threshold = MISSING_VALUES_THRESHOLD) where {T}
    try
        @assert threshold >= 0 && threshold < 1.0 "Threshold must be ∈ [0,1)"
        n_missings = sum(ismissing.(v))
        n_nothings = sum(isnothing.(v))
        n = length(v)
        if (n_missings >= threshold * n) | (n_nothings >= threshold * n) | (n_missings + n_nothings >= threshold * n)
            return FailedCheck(info = (n_missings = n_missings, n_nothings = n_nothings, n = n, threshold = threshold))
        else
            return PassedCheck(info = (n_missings = n_missings, n_nothings = n_nothings, n = n, threshold = threshold))
        end
    catch e
        return NotAvailableCheck(info = string(e))
    end
end


has_negative_values(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_negative_values(::Type{<:StringEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_negative_values(::Type{<:NumericEltype}, v, vm, name, args...; kwargs...) = any(<(0), vm) ? FailedCheck(nothing) : PassedCheck(nothing)

const PERC_MINORITY_CLASS = 0.01

process_column_for_indexing(col::Number) = Int(col)
process_column_for_indexing(col::AbstractString) = Symbol(col)
process_column_for_indexing(col::Symbol) = col
process_column_for_indexing(::Nothing) = nothing

function is_imbalanced_target_variable(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        threshold = PERC_MINORITY_CLASS
    )
    try
        col = linting_ctx.target_variable
        tc = getindex(tblref[], process_column_for_indexing(col))
        n = length(tc)
        cm = countmap(tc)
        vals = []
        for (val, cnt) in cm
            cnt / n < threshold && push!(vals, val)
        end
        if !isempty(vals)
            return FailedCheck(info = vals)
        else
            return PassedCheck(nothing)
        end
    catch e
        @debug "is_imbalanced_target_variable: Failed\n$e"
        return NotAvailableCheck(info = string(e))
    end
end

is_imbalanced_target_variable(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)


const DEFAULT_VIF_THRESHOLD = 10.0

"""
Check if any variable has high Variance Inflation Factor (VIF).
VIF measures how much the variance of a regression coefficient increases due to colinearity.
Returns true if any VIF exceeds threshold, false otherwise.
"""
function high_vif(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        vif_threshold = DEFAULT_VIF_THRESHOLD
    )
    try
        data_matrix = Tables.matrix(tblref[])
        good_columns = vec(sum(ismissing.(data_matrix), dims = 1)) .!= size(data_matrix, 1)
        data_clean = data_matrix[:, good_columns]
        size(data_clean, 2) < 2 && return PassedCheck(info = "less than 2 columns available")
        data_clean[ismissing.(data_clean)] .= 0
        columns_clean = Tables.columnnames(tblref[])[good_columns]
        try
            vif_values = diag(inv(cor(data_clean)))
            if any(vif_values .> vif_threshold)
                return FailedCheck(info = vif_values)
            else
                return PassedCheck(nothing)
            end
        catch
            return FailedCheck(info = "singular matrix, perfect multicolinearity")
        end
    catch e
        return NotAvailableCheck(info = string(e))
    end
end

const DEFAULT_CNC_THRESHOLD = 100.0

"""
Check if the condition number of the correlation matrix indicates severe colinearity.
Condition number is the ratio of the largest to smallest eigenvalue.
High condition number indicates numerical instability due to colinearity.
"""
function condition_number_check(
        tblref::Base.RefValue{<:Tables.AbstractColumns},
        linting_ctx,
        args...;
        cnc_threshold = DEFAULT_CNC_THRESHOLD
    )
    try
        data_matrix = Tables.matrix(tblref[])
        good_columns = vec(sum(ismissing.(data_matrix), dims = 1)) .!= size(data_matrix, 1)
        data_clean = data_matrix[:, good_columns]
        size(data_clean, 2) < 2 && return PassedCheck(info = "less than 2 columns available")
        data_clean[ismissing.(data_clean)] .= 0
        eigenvalues = eigvals(cor(data_clean))
        cond_num = maximum(abs.(eigenvalues)) / minimum(abs.(eigenvalues) .+ 1.0e-10)
        if cond_num >= cnc_threshold
            return FailedCheck(info = cond_num)
        else
            return PassedCheck(nothing)
        end
    catch e
        return NotAvailableCheck(info = string(e))
    end
end

const EXTENDED_BASELINE_LINTERS = [
    # No missing values in the column
    (
        name = :many_missing_values,
        description = """ Tests that few missing values exist in variable """,
        f = has_many_missing_values,
        failure_message = (name, result) -> "'$name' has more than $(result.info.threshold * 100)% missing values",
        correct_message = (name, result) -> "'$name' has less than $(result.info.threshold * 100)% missing values",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # No negative values in the column
    (
        name = :negative_values,
        description = """ Tests that no negative values exist in variable """,
        f = has_negative_values,
        failure_message = (name, args...) -> "found negative values in '$name'",
        correct_message = (name, args...) -> "no negative values in '$name'",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # Imbalanced data
    (
        name = :imbalanced_target_variable,
        description = """ Tests that data labels are balanced (no class less than θ%)""",
        f = is_imbalanced_target_variable,
        failure_message = (name, result) -> "Imbalanced target column in '$name' for values=$(process_for_printing(result.info))",
        correct_message = (name, args...) -> "Data is balanced in target column '$name'",
        warn_level = "warning",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Colinearity (using VIF)
    (
        name = :vif_colinearity,
        description = """ Tests if variables in the dataset exhibit high multicolinearity using VIF and correlation analysis""",
        f = high_vif,
        failure_message = (name, args...) -> "High multicolinearity detected in dataset using VIF",
        correct_message = (name, args...) -> "No high multicolinearity detected using VIF",
        warn_level = "warning",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset),
    ),

    # Colinearity (using critical number)
    (
        name = :cnc_colinearity,
        description = """ Tests if variables in the dataset exhibit high multicolinearity using condition number analysis""",
        f = condition_number_check,
        failure_message = (name, result) -> "High multicolinearity detected, condition number=$(result.info)",
        correct_message = (name, result) -> "No high multicolinearity detected, condition number=$(result.info)",
        warn_level = "warning",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset),
    ),
]
