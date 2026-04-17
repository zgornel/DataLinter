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


const EXPERIMENTAL_LINTERS = [
    # No missing values in the column
    (
        name = :many_missing_values,
        description = """ Tests that few missing values exist in variable """,
        f = has_many_missing_values,
        failure_message = name -> "found many missing values in '$name'",
        correct_message = name -> "few or no missing values in '$name'",
        warn_level = "experimental",
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
        warn_level = "experimental",
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
        warn_level = "experimental",
        correct_if = check_correctness(false),
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset, "linting_ctx" => true),
    ),
]
