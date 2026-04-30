is_int_as_float(::Type{<:StringEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_int_as_float(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_int_as_float(::Type{<:NumericEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

is_int_as_float(::Type{<:FloatEltype}, v, vm, name, args...; kwargs...) = all(isinteger.(vm)) ? FailedCheck(nothing) : PassedCheck(nothing)


is_datetime_as_string(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_datetime_as_string(::Type{<:NumericEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_datetime_as_string(::Type{<:FloatEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

const DATETIME_MATCH_PERC = 0.9
function is_datetime_as_string(::Type{<:StringEltype}, v, vm, name, args...; match_perc = DATETIME_MATCH_PERC)
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
    _vm = collect(vm)
    matches = Dict{Int, Int}()
    for (i, rdt) in enumerate(DATETIME_REGEXES)
        # count how many matches of the expression are in the column
        push!(matches, i => sum(.!isnothing.(match.(rdt, _vm))))
    end
    # Strict output, needs at least one expression to fully match the column
    if any(count_matches > match_perc * length(_vm) for count_matches in values(matches))
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


is_tokenizable_string(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_tokenizable_string(::Type{<:NumericEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_tokenizable_string(::Type{<:FloatEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

const TOKENIZABLE_REGEXES = [r"\s+"]
const MIN_TOKENS = 2
function is_tokenizable_string(::Type{<:StringEltype}, v, vm, name, args...; regexes = TOKENIZABLE_REGEXES, min_tokens = MIN_TOKENS)
    _vm = collect(vm)
    matches = Dict{Int, Int}()
    for (i, rdt) in enumerate(regexes)
        # count how many matches of the expression are in the column
        push!(matches, i => sum(.!isnothing.(match.(rdt, _vm))))
    end
    if any(count_matches > min_tokens - 1 for count_matches in values(matches))
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


is_number_as_string(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_number_as_string(::Type{<:NumericEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_number_as_string(::Type{<:FloatEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

const NUMBER_AS_STRING_MATCH_PERC = 0.9
function is_number_as_string(::Type{<:StringEltype}, v, vm, name, args...; match_perc = NUMBER_AS_STRING_MATCH_PERC)
    NUMBER_REGEXES = [
        # Regex from https://stackoverflow.com/questions/12643009/regular-expression-for-floating-point-numbers#12643073
        r"^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$",
    ]
    _vm = collect(vm)
    matches = Dict{Int, Int}()
    for (i, rdt) in enumerate(NUMBER_REGEXES)
        # count how many matches of the expression are in the column
        push!(matches, i => sum(.!isnothing.(match.(rdt, _vm))))
    end
    if any(count_matches > match_perc * length(_vm) for count_matches in values(matches))
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


function is_empty_example(row, args...; kwargs...)
    #TODO: improve performance
    empty_checker(::Missing) = true
    empty_checker(v::FloatEltype) = isnan(v)
    empty_checker(v::NumericEltype) = isnan(v)
    empty_checker(v) = isempty(v)
    out = true
    for v in row  # name of column is ommitted
        out &= empty_checker(v)
        !out && break  # stop if encountered a false value
    end
    if out
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


is_zipcode(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
is_zipcode(::Type{<:FloatEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

const NUM_ZIPCODES = [9000, 9001, 1000, 1010, 1020, 1030, 1040, 1050, 1060, 1070, 1080, 1090, 1100]
const ZIPCODES_MATCH_PERC = 0.99
function is_zipcode(
        typ::Type{T}, v, vm, name, args...;
        match_perc = ZIPCODES_MATCH_PERC,
        zipcodes = NUM_ZIPCODES
    ) where {T <: Union{<:StringEltype, <:NumericEltype}}
    zipcodes_strings = string.(zipcodes)
    _count_in_zipcode(::Type{<:NumericEltype}, vm) = sum(z in zipcodes for z in vm)
    _count_in_zipcode(::Type{<:StringEltype}, vm) = sum(z in zipcodes_strings for z in vm)
    if _count_in_zipcode(typ, vm) >= match_perc * length(collect(vm))
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


function has_duplicates(tblref::Base.RefValue{<:Tables.Columns}, args...; kwargs...)
    _rows = Tables.rows(tblref[])
    if length(unique(hash(r) for r in _rows)) != length(_rows)
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


has_large_outliers(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_large_outliers(::Type{<:StringEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

"""
    tukey_fences(data; k=1.5)

Compute the values beyond which elements of `data` are considered anomalous by
to Tukey (1977; John W, Exploratory Data Analysis, Addison-Wesley, ISBN
0-201-07616-0, OCLC 3058187).  Larger values of `k` consider fewer elements
to be anomalous.
"""
function tukey_fences(data; k = 1.5)
    q1, q3 = quantile(data, [0.25, 0.75])
    iqr = q3 - q1
    fence = k * iqr
    return q1 - fence, q3 + fence
end

const TUKEY_FENCES_K = 1.5
function has_large_outliers(::Type{<:NumericEltype}, v, vm, name, args...; tukey_fences_k = TUKEY_FENCES_K)
    minf, maxf = tukey_fences(vm; k = tukey_fences_k)
    if any(x -> ((x < minf) | (x > maxf)), vm)
        return FailedCheck(info = (tukey_fences = (minf, maxf),))
    else
        return PassedCheck(nothing)
    end
end


const ENUM_DETECTOR_DISTINCT_RATIO = 0.001
const ENUM_DETECTOR_MAX_LIMIT = 5
function enum_detector(
        ::T, v, vm, name, args...;
        distinct_ratio = ENUM_DETECTOR_DISTINCT_RATIO,
        distinct_max_limit = ENUM_DETECTOR_MAX_LIMIT
    ) where {T}
    # if unique values < distinct_ratio % of the total number => we have an enum
    n_uniques = length(unique(vm))
    n = length(collect(vm))
    if (n_uniques <= floor(distinct_ratio * n) + 1) | (n_uniques < distinct_max_limit)
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


has_uncommon_signs(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_uncommon_signs(::Type{<:StringEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_uncommon_signs(::T, args...; kwargs...) where {T} = NotAvailableCheck(nothing)

#TODO: See if it makes sense to make this configurable through kwargs
function has_uncommon_signs(::Type{<:NumericEltype}, v, vm, name, args...; kwargs...)
    sgns = sign.(vm)
    zs = sum(sgns .== 0)
    negs = sum(sgns .< 0)
    poss = sum(sgns .> 0)
    nans = sum(sgns .== NaN)
    # dataset dimension range => max number of positive, negative, zeros, NaNs
    # that may count as uncommon signs given the dimension of the data
    # i.e. if the dataset has 100 samples one '-', '+' or 'NaN' would trigger the linter
    ranges = [
        1:1000 => 2,
        1001:100_000 => 5,
        100_000:1_000_000 => 10,
    ]
    r_outlier = try
        first(v for (k, v) in ranges if length(v) in k)
    catch # bounds error, many samples
        20
    end
    if any(cnt in 1:r_outlier for cnt in (zs, negs, poss, nans))
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


has_long_tailed_distribution(::Type{<:ListEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_long_tailed_distribution(::Type{<:StringEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

const LTD_DROP_PROPORTION = 0.001
const LTD_ZSCORE_MULTIPLIER = 1.0
function has_long_tailed_distribution(
        ::Type{<:NumericEltype}, v, vm, name, args...;
        drop_proportion = LTD_DROP_PROPORTION,
        zscore_multiplier = LTD_ZSCORE_MULTIPLIER
    )
    v = collect(vm)
    vt = trim(v, prop = drop_proportion)
    μ, σ = mean_and_std(vt)
    zs = abs.(zscore(v, μ, σ))
    n_outliers = sum(zs .>= zscore_multiplier * mean(zs))
    if n_outliers > 0
        return FailedCheck(info = n_outliers)
    else
        return PassedCheck(nothing)
    end
end


function has_circular_domain(::T, v, vm, name, args...; kwargs...) where {T}
    # This one looks only at column name. Courtesy of:
    # `https://github.com/brain-research/data-linter/blob/master/linters.py#L966C3-L973C1`
    CIRCULAR_NAME_REGEXES = [
        r"deg([\W_]|\b)", r"(wind.*|^)degrees?$", r"rad([\W_]|ian|\b)",                 # degree
        r"(month|week|day|time|hour|min(ute)?|sec(ond)?)[\W_]?o[f\W_]",                 # x of y
        r"^(week|day|hour|month|(milli|micro)?sec((ond)?s?)|minutes?)$",                # times
        r"([\W_]|\b)(lat|lon)([\W_]|\b|\w*?itude)",                                     # latlon
        r"([\W_]|\b)angle([\W_]|\b)", r"heading", r"rotation", r"dir([\w]*|ection)",
    ]    # directions
    if any(!isnothing(match(re, string(name))) for re in CIRCULAR_NAME_REGEXES)
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


has_uncommon_list_lengths(::Type{<:NumericEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_uncommon_list_lengths(::Type{<:StringEltype}, args...; kwargs...) = NotAvailableCheck(nothing)
has_uncommon_list_lengths(::Type{<:TimeEltype}, args...; kwargs...) = NotAvailableCheck(nothing)

function has_uncommon_list_lengths(::Type{<:ListEltype}, v, vm, name, args...; kwargs...)
    lens = map(length, vm)
    are_lists = length(collect(Iterators.flatten(vm))) != length(collect(vm))
    if are_lists && length(unique(lens)) > 1
        return FailedCheck(nothing)
    else
        return PassedCheck(nothing)
    end
end


# Linters from http://learningsys.org/nips17/assets/papers/paper_19.pdf
const GOOGLE_BASELINE_LINTERS = [
    # 1. DateTime wrongly encoded as string
    (
        name = :datetime_as_string,
        description = """ Tests that the values string variable could be Date/DateTime(s) """,
        f = is_datetime_as_string,
        failure_message = (name, args...) -> "most of the string values of '$name' can be converted to times/dates",
        correct_message = (name, args...) -> "the string values of '$name' generally cannot be converted to times/dates",
        warn_level = "important",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 2. Tokenizable string i.e. too long, with spaces
    (
        name = :tokenizable_string,
        description = """ Tests if the values of the string variable are tokenizable i.e. contain spaces """,
        f = is_tokenizable_string,
        failure_message = (name, args...) -> "the values of '$name' could be tokenizable i.e. contain spaces",
        correct_message = (name, args...) -> "the values of '$name' are not tokenizable i.e. no spaces",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 3. Number wrongly encoded as string
    (
        name = :number_as_string,
        description = """ Tests if the values of the string variable could be parsed as numbers """,
        f = is_number_as_string,
        failure_message = (name, args...) -> "most of the string values of '$name' can be converted to numbers",
        correct_message = (name, args...) -> "the string values of '$name' generally cannot be converted to numbers",
        warn_level = "important",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 4. Zipcode wrongly encoded as number (tip: use zipcode list)
    (
        name = :zipcodes_as_values,
        description = """ Tests if the values of the numerical variable could be zipcodes """,
        f = is_zipcode,
        failure_message = (name, args...) -> "many of the values of '$name' could be zipcodes",
        correct_message = (name, args...) -> "many the values of '$name' don't look like zipcodes",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 5. Large outliers
    (
        name = :large_outliers,
        description = """ Tests that the values of a numerical variable do not contain large outliers """,
        f = has_large_outliers,
        failure_message = (name, args...) -> "the values of '$name' contain large outliers",
        correct_message = (name, args...) -> "there do not seem to be large outliers in '$name'",
        warn_level = "warning",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 6. Int-as-float wrong encoding
    (
        name = :int_as_float,
        description = """ Tests that no the values of a floating point variable can be converted to integers """,
        f = is_int_as_float,
        failure_message = (name, args...) -> "the values of '$name' are floating point but can be integers",
        correct_message = (name, args...) -> "no int-as-float in '$name'",
        warn_level = "warning",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 7. enum detector i.e. few distinct values, treat as categorical instead of whatever type
    (
        name = :enum_detector,
        description = """ Tests that a variable has few variables and could be an enum """,
        f = enum_detector,
        failure_message = (name, args...) -> "just a few distinct values in '$name', it could be an enum",
        correct_message = (name, args...) -> "'$name' has quite a few values, unlikely to be an enum",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 8. uncommon list length
    (
        name = :uncommon_list_lengths,
        description = """ Tests that the variable does not contain uncommon list lengths in its values """,
        f = has_uncommon_list_lengths,
        failure_message = (name, args...) -> "values in '$name' are lists inconsistent in length",
        correct_message = (name, args...) -> "'$name' does not contain lists incosistent in length",
        warn_level = "warning",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 9. duplicate examples (row based, not column based)
    (
        name = :duplicate_examples,
        description = """ Tests that the dataset does not contain duplicates """,
        f = has_duplicates,
        failure_message = (name, args...) -> "dataset contains duplicates",
        correct_message = (name, args...) -> "the dataset does not contain duplicates",
        warn_level = "important",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :dataset),
    ),

    # 10. empty examples
    (
        name = :empty_example,
        description = """ Tests that no example is completely empty """,
        f = is_empty_example,
        failure_message = (index, args...) -> "the example at '$index' looks empty",
        correct_message = (index, args...) -> "the example at '$index' is not empty",
        warn_level = "important",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :row),
    ),

    # 11. uncommon sign i.e. +/-/0/nan
    (
        name = :uncommon_signs,
        description = """ Tests for the existence of uncommon signs (+/-/NaN) in the variable """,
        f = has_uncommon_signs,
        failure_message = (name, args...) -> "uncommon signs (+/-/NaN/0) present in '$name'",
        correct_message = (name, args...) -> "no uncommon signs (+/-/NaN/0) present in '$name'",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 12. tailed distribution i.e. extrema that affects the mean
    (
        name = :long_tailed_distrib,
        description = """ Tests if the distribution of the variable has long tails """,
        f = has_long_tailed_distribution,
        failure_message = (name, args...) -> "the distribution for '$name' has 'long tails'",
        correct_message = (name, args...) -> "no 'long tails' in the distribution of '$name'",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),

    # 13. circular domain detector i.e. angles, hours, latitude/longitude
    (
        name = :circular_domain,
        description = """ Tests if the domain of the variable may be circular""",
        f = has_circular_domain,
        failure_message = (name, args...) -> "the name of '$name' indicates its values may have a circular domain",
        correct_message = (name, args...) -> "the name of '$name' do not indicate its values having a circular domain",
        warn_level = "info",
        query = nothing,
        programming_language = nothing,
        requirements = Dict("iterable_type" => :column),
    ),
]
