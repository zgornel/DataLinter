#TODO: Move the logic from code into a knowledge-base object of some sort#
using DataFrames
using StatsBase

#TODO: Remove column from input arguments, add eltype traits
#1. Add the types:
#  NumericColumEltype = Union{<:AbstractFloat, Union{Missing, <:AbstractFloat}}
#  StringColumEltype = Union{<:AbstractString, Union{Missing, <:AbstractString}}
#  ListColumnEltype = Union{Any, Vector{Any}}
#
#2. Add signatures of the type:
#  is_int_as_float(::T, v, vm, args...) where T<:NumericColumnEltype = ...
#  is_int_as_float(::T, v, vm, args...) where T<:StringColumnEltype = ...
#
#3. In the linter data structure replace functions with pipelines:
#     f --> f ∘ select_specific_inputs ∘ destructure_column
#     f should take only minimal arguments

destructure_column(column) = begin
    (_name, _eltype), _values = column
    _vs = skipmissing(_values)
    # TODO: move iterators and perhaps statistics (i.e. counts)
    #       to the column iterator in `src/data.jl`
    return _name, _eltype, _values, _vs
end

check_correctness(check_against) =
    (result)->begin
        if result === nothing
            return nothing
        elseif result==check_against
            return true
        else
            return false
        end
    end

function is_int_as_float(column, args...)
    _, t, _, vm = destructure_column(column)
    if !(t <: AbstractFloat || t <: Union{Missing, <:AbstractFloat})
        return nothing
    else try
            for v in vm
                Int(v)
            end
            return true
        catch e;
            return false
        end
    end
end

function is_datetime_as_string(column, args...)
    DATETIME_REGEXES = [
        # RFC 2822 Date Format Regular Expression from https://regexpattern.com/rfc-2822-date/
        r"^(?:(Sun|Mon|Tue|Wed|Thu|Fri|Sat),\s+)?(0[1-9]|[1-2]?[0-9]|3[01])\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(19[0-9]{2}|[2-9][0-9]{3})\s+(2[0-3]|[0-1][0-9]):([0-5][0-9])(?::(60|[0-5][0-9]))?\s+([-\+][0-9]{2}[0-5][0-9]|(?:UT|GMT|(?:E|C|M|P)(?:ST|DT)|[A-IK-Z]))(\s+|\(([^\(\)]+|\\\(|\\\))*\))*$",
        # All-in-one Datetime Regular Expression from https://regexpattern.com/all-in-one-datetime/
        r"(?=\d)^(?:(?!(?:10\D(?:0?[5-9]|1[0-4])\D(?:1582))|(?:0?9\D(?:0?[3-9]|1[0-3])\D(?:1752)))((?:0?[13578]|1[02])|(?:0?[469]|11)(?!\/31)(?!-31)(?!\.31)|(?:0?2(?=.?(?:(?:29.(?!000[04]|(?:(?:1[^0-6]|[2468][^048]|[3579][^26])00))(?:(?:(?:\d\d)(?:[02468][048]|[13579][26])(?!\x20BC))|(?:00(?:42|3[0369]|2[147]|1[258]|09)\x20BC))))))|(?:0?2(?=.(?:(?:\d\D)|(?:[01]\d)|(?:2[0-8])))))([-.\/])(0?[1-9]|[12]\d|3[01])\2(?!0000)((?=(?:00(?:4[0-5]|[0-3]?\d)\x20BC)|(?:\d{4}(?!\x20BC)))\d{4}(?:\x20BC)?)(?:$|(?=\x20\d)\x20))?((?:(?:0?[1-9]|1[012])(?::[0-5]\d){0,2}(?:\x20[aApP][mM]))|(?:[01]\d|2[0-3])(?::[0-5]\d){1,2})?$",
        # Date (dd/mm/yyyy) Regular Expression from https://regexpattern.com/date-dd-mm-yyyy/
        r"(?:(?:31(\/|-|\.)(?:0?[13578]|1[02]))\1|(?:(?:29|30)(\/|-|\.)(?:0?[13-9]|1[0-2])\2))(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)0?2\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9])|(?:1[0-2]))\4(?:(?:1[6-9]|[2-9]\d)?\d{2})",
        # 24-Hour Time (HH:mm:ss) Regular Expression from https://regexpattern.com/24-hour-time/
        r"^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$",
        # 12-Hour Time (hh:mm:ss) Regular Expression from https://regexpattern.com/12-hour-time/
        r"^(?:1[0-2]|0?[1-9]):[0-5]\d:[0-5]\d$",
        ### Regex To Match ISO 8601 Dates and Times from https://regexpattern.com/iso-8601-dates-times/
        r"^([0-9]{4})-(1[0-2]|0[1-9])$",  # ISO 8601 for year and month
        r"^([0-9]{4})-?(1[0-2]|0[1-9])-?(3[01]|0[1-9]|[12][0-9])$", # ISO 8601 for dates like 2020-12-29 and 20201229
        r"^(-?(?:[1-9][0-9]*)?[0-9]{4})-(1[0-2]|0[1-9])-(3[01]|0[1-9]|[12][0-9])(Z|[+-](?:2[0-3]|[01][0-9]):[0-5][0-9])?$",  # ISO 8601 date with an optional time zone 2020-12-29-07:00
        r"^([0-9]{4})-?W(5[0-3]|[1-4][0-9]|0[1-9])$",  # ISO 8601 week of the year like 2020-W40
        r"^(2[0-3]|[01][0-9]):?([0-5][0-9])$", # ISO 8601 time format (Hours and Minutes) like 19:30
        r"^(2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])$",  # ISO 8601 time format (Hours, minutes, and seconds) like 19:30:45
        r"^(2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])(Z|[+-](?:2[0-3]|[01][0-9])(?::?(?:[0-5][0-9]))?)$",  #  ISO 8601 time format (Hours, minutes, and seconds with timezone) like 19:30:45-05:00
        r"^([0-9]{4})-?(1[0-2]|0[1-9])-?(3[01]|0[1-9]|[12][0-9]) (2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])$", # ISO 8601 date with hours, minutes, and seconds like 2020-12-29 19:30:45 or 20201229 193045
        r"^(-?(?:[1-9][0-9]*)?[0-9]{4})-(1[0-2]|0[1-9])-(3[01]|0[1-9]|[12][0-9])T(2[0-3]|[01][0-9]):([0-5][0-9]):([0-5][0-9])(\.[0-9]+)?(Z|[+-](?:2[0-3]|[01][0-9]):[0-5][0-9])?$",  # ISO 8601 date with optional fractional seconds and time zone like 2020-12-29T19:30:45 or 2020-12-29T19:30:45.123Z
    ]
    _, t, _, vm = destructure_column(column)
    if !( t <: AbstractString || t <: Union{Missing, <:AbstractString})
        return nothing  # if column is not string, don't bother, check passes
    end
    _vm = collect(vm)
    matches = Dict{Int, Int}()
    for (i, rdt) in enumerate(DATETIME_REGEXES)
        # count how many matches of the expression are in the column
        push!(matches, i => sum(.!isnothing.(match.(rdt, _vm))))
    end
    # TODO: Improve the logic here
    # Strinct output, needs at least one expression to fully match the column
    return any(count_matches > 0.9 * length(_vm) for count_matches in values(matches))
end

function is_tokenizable_string(column, args...)
    TOKENIZABLE_REGEXES = [
        r"\s+"
    ]
    _, t, _, vm = destructure_column(column)
    if !( t <: AbstractString || t <: Union{Missing, <:AbstractString})
        return nothing  # if column is not string, don't bother, check passes
    end
    _vm = collect(vm)
    matches = Dict{Int, Int}()
    for (i, rdt) in enumerate(TOKENIZABLE_REGEXES)
        # count how many matches of the expression are in the column
        push!(matches, i => sum(.!isnothing.(match.(rdt, _vm))))
    end
    return any(count_matches > 0 for count_matches in values(matches))
end

function is_number_as_string(column, args...)
    NUMBER_REGEXES = [
         # Regex from https://stackoverflow.com/questions/12643009/regular-expression-for-floating-point-numbers#12643073
        r"^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$"
    ]
    _, t, _, vm = destructure_column(column)
    if !( t <: AbstractString || t <: Union{Missing, <:AbstractString})
        return nothing  # if column is not string, don't bother, check passes
    end
    _vm = collect(vm)
    matches = Dict{Int, Int}()
    for (i, rdt) in enumerate(NUMBER_REGEXES)
        # count how many matches of the expression are in the column
        push!(matches, i => sum(.!isnothing.(match.(rdt, _vm))))
    end
    return any(count_matches > 0.9 * length(_vm) for count_matches in values(matches))
end

function is_empty_example(row, args...)
    NUMBER_REGEXES = [
        # Regex from https://stackoverflow.com/questions/12643009/regular-expression-for-floating-point-numbers#12643073
        r"^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$"
    ]
    is_empty = Bool[]
    #TODO: Improve logic, checks below
    for (k,v) in row
        if ismissing(v)
            push!(is_empty, true)
        elseif typeof(v) <: Number || typeof(v) <: Union{Missing, <:Number}
            push!(is_empty, isnan(v))
        elseif typeof(v) <: AbstractString || typeof(v) <: Union{Missing, <:AbstractString}
            push!(is_empty, isempty(v))
        else
            push!(is_empty , isempty(v))
        end
    end
    return all(is_empty)
end

NUM_ZIPCODES = [9000, 9001, 1000, 1010, 1020, 1030, 1040, 1050, 1060, 1070, 1080, 1090, 1100]
STR_ZIPCODES = string.(NUM_ZIPCODES)
#TODO: Make lists of zipcodes, make them configurable (there are many numbers)
function is_zipcode(column, args...)
    _, t, _, vm = destructure_column(column)
    _count_in_zipcode(v) = sum(z in NUM_ZIPCODES for z in v)
    _count_in_zipcode(v::Vector{<:AbstractString}) = sum(z in STR_ZIPCODES for z in v)
    _count_in_zipcode(v::Vector{Union{Missing, <:AbstractString}}) = sum(z in STR_ZIPCODES for z in v)
    return _count_in_zipcode(vm) >= 0.9 * length(collect(vm))
end

has_duplicates(dfref, args...) = sum(nonunique(dfref[])) != 0

function has_large_outliers(column, args...)
    n, t, _, vm = destructure_column(column)
    if !( t <: Number || t <: Union{Missing, <:Number})
        return nothing
    end
    # simple logic: if we remove X% (X~1%) of the values:
    # the maxmimum changes 'a lot' (more than 2x) as we
    # remove the smallest and largest absolute values
    trim_maxs = Float64[]
    for t in [0, 0.01, 1, 5, 10]
        if t > 0 && t < 1
            try
                push!(trim_maxs, maximum(abs.(trim(collect(vm), prop=t))))
            catch
            end
        else
            try
                push!(trim_maxs, maximum(abs.(trim(collect(vm), count=Int(t)))))
            catch
            end
        end
    end
    return maximum(trim_maxs) >= 2 * minimum(trim_maxs)
end

function enum_detector(column, args...)
    _, _, _, vm = destructure_column(column)
    # if unique values < tol% of the total number => we have an enum
    return length(unique(vm)) <= floor(0.01 * length(collect(vm))) + 1
end

function has_uncommon_signs(column, args...)
    n, t, v = destructure_column(column)
    if !( t <: Number || t <: Union{Missing, <:Number})
        return nothing  # if column is not string, don't bother, check passes
    end
    sgns = sign.(skipmissing(v))
    zs = sum(sgns.== 0)
    negs = sum(sgns.< 0)
    poss = sum(sgns.> 0)
    nans = sum(sgns.== NaN)
    # dataset dimension range => max outlier number
    # TODO: Revise heuristic
    ranges = [1:1000 => 2,
              1001=>100_000 => 5,
              100_000:1_000_000 => 10];
    r_outlier = try
            first(v for (k,v) in ranges if length(v) in k)
        catch # bounds error, over no range found
            20
        end
    return any(cnt in 1:r_outlier for cnt in (zs, negs, poss, nans))
end

function has_tailed_distribution(column, args...)
    #TODO: Implement
end

function has_circular_domain(column, args...)
    #TODO: Implement
end

function has_uncommon_list_lengths(column, args...)
    _, t, _, vm = destructure_column(column)
    lens = map(length, vm)
    # t == Any marks that the type was not correctly inferred
    are_lists = t == Any && (length(collect(Iterators.flatten(vm))) != length(collect(vm)))
    if are_lists && length(unique(lens)) > 1
        return true
    else
        return false
    end
end

# Linters from http://learningsys.org/nips17/assets/papers/paper_19.pdf
const GOOGLE_DATA_LINTERS = [
     # 1. DateTime wrongly encoded as string
     (name = :datetime_as_string,
      description = """ Tests that the values string variable could be Date/DateTime(s) """,
      f = is_datetime_as_string,
      failure_message = name->"most of the string values of '$name' can be converted to times/dates",
      correct_message = name->"the string values of '$name' generally cannot be converted to times/dates",
      warn_level = "warning",
      correct_if = check_correctness(false)
      ),

     # 2. Tokenizable string i.e. too long, with spaces
     (name = :tokenizable_string,
      description = """ Tests if the values of the string variable are tokenizable i.e. contain spaces """,
      f = is_tokenizable_string,
      failure_message = name->"the values of '$name' could be tokenizable i.e. contain spaces",
      correct_message = name->"the values of '$name' are not tokenizable i.e. no spaces",
      warn_level = "info",
      correct_if = check_correctness(false)
      ),

     # 3. Number wrongly encoded as string
     (name = :number_as_string,
      description = """ Tests if the values of the string variable could be parsed as numbers """,
      f = is_number_as_string,
      failure_message = name->"most of the string values of '$name' can be converted to numbers",
      correct_message = name->"the string values of '$name' generally cannot be converted to numbers",
      warn_level = "info",
      correct_if = check_correctness(false)
      ),

     # 4. Zipcode wrongly encoded as number (tip: use zipcode list)
     (name = :zipcodes_as_values,
      description = """ Tests if the values of the numerical variable could be zipcodes """,
      f = is_zipcode,
      failure_message = name->"many of the values of '$name' could be zipcodes",
      correct_message = name->"many the values of '$name' don't look like zipcodes",
      warn_level = "warning",
      correct_if = check_correctness(false)
      ),

     # 5. Large outliers
     (name = :large_outliers,
      description = """ Tests that the values of a numerical variable do not contain large outliers """,
      f = has_large_outliers,
      failure_message = name->"the values of '$name' contain large outliers",
      correct_message = name->"there do not seem to be large outliers in '$name'",
      warn_level = "info",
      correct_if = check_correctness(false)
      ),

     # 6. Int-as-float wrong encoding
     (name = :int_as_float,
      description = """ Tests that no the values of a floating point variable can be converted to integers """,
      f = is_int_as_float,
      failure_message = name->"the values of '$name' are floating point but can be integers",
      correct_message = name->"no int-as-float in '$name'",
      warn_level = "warning",
      correct_if = check_correctness(false)
      ),

     # 7. enum detector i.e. few distinct values, treat as categorical instead of whatever type
     (name = :enum_detector,
      description = """ Tests that a variable has few variables and could be an enum """,
      f = enum_detector,
      failure_message = name->"just a few distinct values in '$name', it could be an enum",
      correct_message = name->"'$name' has quite a few values, unlikely to be an enum",
      warn_level = "warning",
      correct_if = check_correctness(false)
      ),

     # 8. uncommon list length
     (name = :uncommon_list_lengths,
      description = """ Tests that the variable does not contain uncommon list lengths in its values """,
      f = has_uncommon_list_lengths,
      failure_message = name->"values in '$name' are lists inconsistent in length",
      correct_message = name->"'$name' does not contain lists incosistent in length",
      warn_level = "warning",
      correct_if = check_correctness(false)
      ),

     # 9. duplicate examples (row based, not column based)
     (name = :duplicate_examples,
      description = """ Tests that the dataset does not contain duplicates """,
      f = has_duplicates,
      failure_message = name->"dataset contains duplicates",
      correct_message = name->"the dataset does not contain duplicates",
      warn_level = "info",
      correct_if = check_correctness(false)
      ),

     # 10. empty examples
     (name = :empty_example,
      description = """ Tests that no example is completely empty """,
      f = is_empty_example,
      failure_message = name->"the example at '$name' looks empty",
      correct_message = name->"the example at '$name' is not empty",
      warn_level = "warning",
      correct_if = check_correctness(false)
      ),

     # 11. uncommon sign i.e. +/-/0/nan
     (name = :uncommon_signs,
      description = """ Tests for the existence of uncommon signs (+/-/NaN) in the variable """,
      f = has_uncommon_signs,
      failure_message = name->"uncommon signs (+/-/NaN/0) present in '$name'",
      correct_message = name->"no uncommon signs (+/-/NaN/0) present in '$name'",
      warn_level = "warning",
      correct_if = check_correctness(false)
      ),

     # 12. tailed distribution i.e. extrema that affects the mean
     ###(name = :tailed_distribution,
     ### description = """ Tests if the distribution of the variable has long tails """,
     ### f = has_tailed_distribution,
     ### failure_message = name->"The distribution for '$name' has 'long tails'",
     ### correct_message = name->"No 'long tails' in the distribution of variable '$name'",
     ### warn_level = "warning",
     ### correct_if = check_correctness(false)
     ### ),

     # 13. circular domain detector i.e. angles, hours, latitude/longitude
     ###(name = :circular_domain,
     ### description = """ Tests if the domain of the variable may be circular""",
     ### f = has_circular_domain,
     ### failure_message = name->"values in '$name' may have a circular domain",
     ### correct_message = name->"values in '$name' do not look like having a circular domain",
     ### warn_level = "warning",
     ### correct_if = check_correctness(false)
     ### ),
]


function is_many_missings(column, args...)
    _, _, v, _ = destructure_column(column)
    return ( sum(.!ismissing.(v)) + sum(.!isnothing.(v)) ) >= 0.9 * 2 * length(v)
end

function has_negative_values(column, args...)
    _, t, _, vm = destructure_column(column)
    if !(t <: Number || t <: Union{Missing, <:Number})
        return nothing
    end
    return !all(Iterators.map(>(0), vm))
end

const ADDITIONAL_DATA_LINTERS = [
     # No missing values in the column
     ###(name = :missing_values,
     ### description = """ Tests that few missing values exist in variable """,
     ### f = is_many_missings,
     ### failure_message = name->"found many missing values in '$name'",
     ### correct_message = name->"few or no missing values in '$name'",
     ### warn_level = "warning",
     ### correct_if = check_correctness(false)
     ### ),

     # No negative values in the column
     (name = :negative_values,
      description = """ Tests that no negative values exist in variable """,
      f = has_negative_values,
      failure_message = name->"found values smaller than 0 in '$name'",
      correct_message = name->"no values smaller than 0 in '$name'",
      warn_level = "error",
      correct_if = check_correctness(false)
     )
]
