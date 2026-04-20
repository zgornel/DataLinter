using Statistics
using LinearAlgebra

const MISSING_VALUES_THRESHOLD = 0.9
function has_many_missing_values(::T, v, vm, name, args...; threshold = MISSING_VALUES_THRESHOLD) where {T}
    n_missings = sum(ismissing.(v))
    n_nothings = sum(isnothing.(v))
    n = length(v)
    return (n_missings >= threshold * n) | (n_nothings >= threshold * n) |
        (n_missings + n_nothings >= threshold * n)
end


has_negative_values(::Type{<:ListEltype}, args...; kwargs...) = nothing
has_negative_values(::Type{<:StringEltype}, args...; kwargs...) = nothing
has_negative_values(::Type{<:NumericEltype}, v, vm, name, args...; kwargs...) = any(<(0), vm)

const PERC_MINORITY_CLASS = 0.01

__process_target_col(col::Number) = Int(col)
__process_target_col(col::AbstractString) = Symbol(col)
__process_target_col(::Nothing) = nothing

function is_imbalanced_target_variable(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        threshold = PERC_MINORITY_CLASS
    )
    try
        col = linting_ctx.target_variable
        tc = getindex(tblref[], __process_target_col(col))
        n = length(tc)
        for (val, cnt) in countmap(tc)
            cnt / n < threshold && return true
        end
    catch e
        @debug "is_imbalanced_target_variable: Failed\n$e"
        return nothing
    end
    return false
end

is_imbalanced_target_variable(::Type{<:ListEltype}, args...; kwargs...) = nothing


const DEFAULT_VIF_THRESHOLD = 10.0
"""
    high_vif(data_matrix; threshold=10.0)

Check if any variable has high Variance Inflation Factor (VIF).
VIF measures how much the variance of a regression coefficient increases due to colinearity.
Returns true if any VIF exceeds threshold, false otherwise.
"""
function high_vif(data_matrix; vif_threshold = DEFAULT_VIF_THRESHOLD)
    try
        # Remove columns with all missing values
        data_clean = data_matrix[:, vec(sum(ismissing.(data_matrix), dims = 1)) .!= size(data_matrix, 1)]
        size(data_clean, 2) < 2 && return nothing
        corr_matrix = cor(Matrix{Float64}(skipmissing(data_clean)))  # correlation matrix
        try
            vif_values = diag(inv(corr_matrix))
            return any(vif_values .>= threshold)
        catch
            return true  # Singular matrix, indicates perfect multicolinearity
        end
    catch
        return nothing
    end
end

function high_vif(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        vif_threshold = DEFAULT_VIF_THRESHOLD
    )
    return high_vif(Tables.matrix(tblref[]); vif_threshold)
end

const DEFAULT_CNC_THRESHOLD = 100.0

"""
    condition_number_check(data_matrix; threshold=100.0)

Check if the condition number of the correlation matrix indicates severe colinearity.
Condition number is the ratio of the largest to smallest eigenvalue.
High condition number indicates numerical instability due to colinearity.
"""
function condition_number_check(data_matrix; cnc_threshold = DEFAULT_CNC_THRESHOLD)
    try
        # Remove columns with all missing values
        data_clean = data_matrix[:, vec(sum(ismissing.(data_matrix), dims = 1)) .!= size(data_matrix, 1)]
        size(data_clean, 2) < 2 && return nothing
        corr_matrix = cor(Matrix{Float64}(skipmissing(data_clean)))
        eigenvalues = eigvals(corr_matrix)
        cond_num = maximum(abs.(eigenvalues)) / minimum(abs.(eigenvalues) .+ 1.0e-10)
        return cond_num >= threshold
    catch
        return nothing
    end
end

function condition_number_check(
        tblref::Base.RefValue{<:Tables.Columns},
        linting_ctx,
        args...;
        cnc_threshold = DEFAULT_CNC_THRESHOLD
    )
    return condition_number_check(Tables.matrix(tblref[]); cnc_threshold)
end

const EXPERIMENTAL_LINTERS = [
    # No missing values in the column
    (
        name = :many_missing_values,
        description = """ Tests that few missing values exist in variable """,
        f = has_many_missing_values,
        failure_message = name -> "found many missing values in '$name'",
        correct_message = name -> "few or no missing values in '$name'",
        warn_level = "info",
        correct_if = check_correctness(false),
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # No negative values in the column
    (
        name = :negative_values,
        description = """ Tests that no negative values exist in variable """,
        f = has_negative_values,
        failure_message = name -> "found values smaller than 0 in '$name'",
        correct_message = name -> "no values smaller than 0 in '$name'",
        warn_level = "info",
        correct_if = check_correctness(false),
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # Imbalanced data
    (
        name = :imbalanced_target_variable,
        description = """ Tests that data labels are balanced (no class less than θ%)""",
        f = is_imbalanced_target_variable,
        failure_message = name -> "Imbalanced target column in '$name'",
        correct_message = name -> "Data is balanced in target column '$name'",
        warn_level = "warning",
        correct_if = check_correctness(false),
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),

    # Colinearity (using VIF)
    (
        name = :vif_colinearity,
        description = """ Tests if variables in the dataset exhibit high multicolinearity using VIF and correlation analysis""",
        f = high_vif,
        failure_message = name -> "High multicolinearity detected in dataset using VIF",
        correct_message = name -> "No high multicolinearity detected",
        warn_level = "warning",
        correct_if = check_correctness(false),
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset),
    ),

    # Colinearity (using critical number)
    (
        name = :cnc_colinearity,
        description = """ Tests if variables in the dataset exhibit high multicolinearity using condition number analysis""",
        f = condition_number_check,
        failure_message = name -> "High multicolinearity detected in dataset using condition number",
        correct_message = name -> "No high multicolinearity detected using the condition number",
        warn_level = "warning",
        correct_if = check_correctness(false),
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset),
    )
]
