@reexport module LinterCore
using Dates
using Tables
using REPL
using ProgressMeter
using ParSitter
export AbstractLinterContext, lint, version, process_output


# Data Interface
abstract type AbstractDataContext end

function build_data_iterator end  # returns an iterables over data

function get_context_code end

@Base.kwdef struct DataIterator
    column_iterator     # iterate over columns with elements `((name, eltype), [values,...])`
    row_iterator        # iterate over rows with elements `[name => value, name=>value, ...]`
    tblref              # reference to the input data
end

function columnname end # Returns the name of a 'column' element of the `DataIterator`

function columntype end # Returns the type of a 'column' element of the `DataIterator`


# KB Interface
abstract type AbstractKnowledgeBase end

function build_linters end

@Base.kwdef struct Linter
    name::Symbol
    description::String
    f::Function
    failure_message::Function
    correct_message::Function
    warn_level::String
    correct_if::Function
    query::Union{Nothing, Tuple}
    programming_language::Union{Nothing, String}
end

Base.show(io::IO, linter::Linter) = begin
    func = last(split(string(linter.f),"."))
    print(io, "Linter (name=$(linter.name), f=$func)")
end


# Output Interface
function process_output end


# Config Interface
function load_config end
function linter_is_enabled end
function get_linter_kwargs end
function get_experiment_parameters end


# Progress spinner
const SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"


# Linting context
@Base.kwdef mutable struct LinterContext
    name::String = ""
    analysis_type::Union{Nothing, String} = nothing
    analysis_subtype::Union{Nothing, String} = nothing
    target_variable::Union{Nothing, Int, String} = nothing
    data_variables::Union{Nothing, Vector{Int}, Vector{String}} = nothing
    programming_language::Union{Nothing, String} = nothing
    parsing_data = nothing  #::Any
end


"Function that builds a `LinterContext` from code and code query"
function build_linter_context(code::String, query::Tuple, language=nothing)
    language == nothing && return nothing
    try
        # Build query
        query_tree = ParSitter.build_tq_tree(query)
        # Parse code
        code_struct = (ParSitter.Code(code), language)
        _parsed = ParSitter.parse(code_struct...)
        _parsed = first(values(_parsed))
        target_tree = ParSitter.build_xml_tree(_parsed)
        # Query helper functions
        _target_nodevalue(n) = strip(replace(n.content, r"[\s]"=>""))
        _query_nodevalue(n) = ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head,"@")[1]), n.head)
        _apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym="@").is_match || qn.head=="*"
        _capture_function(n) = (v=string(strip(replace(n.content, r"[\s]"=>""))), srow=n["srow"], erow=n["erow"], scol=n["scol"], ecol=n["ecol"])
        # Run query over parsed code
        query_results=ParSitter.query(target_tree.root,
                                      query_tree;
                                      match_type=:strict,
                                      target_tree_nodevalue=_target_nodevalue,
                                      query_tree_nodevalue=_query_nodevalue,
                                      capture_function=_capture_function,
                                      node_comparison_yields_true=_apply_regex_glob)
        filter!(first, query_results) # keep only matches
        if length(query_results) == 0
            throw(ErrorException("No results for query"))
        elseif length(query_results) > 1
            throw(ErrorException("Multiple query matches, query is not specific enough"))
        else
            _parsed_data = query_results[1][2]
            out = LinterContext(name="Online Linter Context [$(now())]")
            for (_key, _captures) in _parsed_data
                @assert length(_captures) == 1 "Multiple captures, query is not specific enough"
                _skey = Symbol(_key)
                if _skey in fieldnames(typeof(out))
                    _val = (first(_captures)).v
                    setfield!(out, _skey, _val)
                end
            end
            setfield!(out, :parsing_data, query_results)
            return out
        end
    catch e
        @warn "Could not parse and apply query over code snippet\n$e"
        nothing
    end
end

"Function that builds a `LinterContext` from a linter configuration"
function build_linter_context(config)
    experiment_ctx = get_experiment_parameters(config)
    if experiment_ctx !== nothing
        return LinterContext(experiment_ctx..., nothing)
    else
        return nothing
    end
end


"""
    lint(ctx::AbstractDataContext, kb::Union{Nothing, AbstractKnowledgeBase}; config=nothing, debug=false, linters=["all"])

Main linting function. Lints the data provided by `ctx` using
knowledge from `kb`. A configuration for the available linters
can be provided in `config`. If `debug=true`, performance information
for each linter are shown. By default, all available linters will be used.
"""
function lint(ctx::AbstractDataContext,
              kb::Union{Nothing, AbstractKnowledgeBase};
              config=nothing,
              debug=false,
              progress=false,
              linters=["all"])
    # TODO: Improve the `lintout` structure to something more workable
    #       that includes timings, outputs, easy referencing i.e. Dict
    lintout = Vector{Pair{Tuple{Linter, String}, Union{Nothing, Bool}}}()
    datait = build_data_iterator(ctx)

    _progress = ProgressUnknown(desc="Linting...", spinner=true, color=:white, showspeed=true)
    _terminal = REPL.Terminals.TTYTerminal("", stdin, stdout, stderr)
    for linter in build_linters(kb, ctx; linters)
        if linter_is_enabled(config, linter)
            linter_kwargs = get_linter_kwargs(config, linter)  # this injects configuration parameters into linter functions
            # Extract more context:
            #  - from the context code (online workflow type)
            #  - from config (cli workflow type)
            code = get_context_code(ctx)
            query = linter.query
            language = linter.programming_language
            linter_ctx = if code != nothing && query != nothing && language != nothing
                            build_linter_context(code, query, language)  # coding workflow
                         elseif config != nothing
                            build_linter_context(config)                 # no coding worflow
                         else
                            #TODO: Improve logic below: reconcile if query, code and config are present
                            nothing
                         end

            _t = @timed begin
                    # Apply linter:
                    #  - run linter function
                    #  - compare result with the one stored in closure for correctness
                    #  - if the result is false i.e. mismatch in values, linter fails (warning displayed)
                    #  - if the result is true i.e. expexted value returned, linter passes
                    # 1. Apply over column
                    if applicable(linter, linter_ctx, :column)
                        for (i, col) in enumerate(datait.column_iterator)
                            _name = columnname(datait, i)
                            _type = columntype(datait, i)
                            result = linter.correct_if(
                                        linter.f(_type, col, skipmissing(col), _name, linter_ctx; linter_kwargs...)
                                     )
                            push!(lintout, (linter, "column: $_name") => result)
                            progress && next!(_progress, spinner=SPINNER)
                        end
                    end
                    # 2. Apply over rows
                    if applicable(linter, linter_ctx, :row)
                        irow = 1
                        no_empty_rows = true
                        for row in datait.row_iterator
                            result = linter.correct_if(
                                        linter.f(row, linter_ctx; linter_kwargs...)
                                     )
                            if !isnothing(result) && !result  # skip trues or nothings as there may be too many
                                push!(lintout, (linter, "row: $irow") => result)
                                no_empty_rows = false
                                progress && next!(_progress, spinner=SPINNER)
                            end
                            irow+= 1
                        end
                        # if there are no empty rows add a single entry, to mark the linter was applied and passed (true)
                        no_empty_rows && push!(lintout, (linter, "row: N/A") => true)
                    end
                    # 3. Apply over whole dataset
                    if applicable(linter, linter_ctx, :dataset)
                        result = linter.correct_if(
                                    linter.f(datait.tblref, linter_ctx; linter_kwargs...)
                                 )
                        push!(lintout, (linter, "dataset") => result)
                        progress && next!(_progress, spinner=SPINNER)
                    end
            end;
            _, _time, _bytes, _gctime, _ = _t;
            debug && @show linter.name, _time, _bytes, _gctime
        end
    end
    progress && REPL.Terminals.clear_line(_terminal)
    return lintout
end


function applicable(linter, linter_ctx, iterable_type)
    if linter.name == :imbalanced_target_variable && iterable_type == :dataset && linter_ctx !== nothing
        ifelse(linter_ctx.target_variable !== nothing, true, false)
    elseif linter.name == :R_glmmTMB_target_variable && iterable_type == :dataset && linter_ctx !== nothing
        return if linter_ctx.target_variable !== nothing && linter_ctx.parsing_data != nothing
            true
        else
            false
        end
    elseif linter.name == :negative_values && iterable_type == :column
        return true
    elseif linter.name == :many_missing_values && iterable_type == :column
        return true
    elseif linter.name == :int_as_float && iterable_type == :column
        return true
    elseif linter.name == :datetime_as_string && iterable_type == :column
        return true
    elseif linter.name == :tokenizable_string && iterable_type == :column
        return true
    elseif linter.name == :number_as_string && iterable_type == :column
        return true
    elseif linter.name == :empty_example && iterable_type == :row
        return true
    elseif linter.name == :zipcodes_as_values && iterable_type == :column
        return true
    elseif linter.name == :duplicate_examples && iterable_type == :dataset
        return true
    elseif linter.name == :large_outliers && iterable_type == :column
        return true
    elseif linter.name == :enum_detector && iterable_type == :column
        return true
    elseif linter.name == :uncommon_signs && iterable_type == :column
        return true
    elseif linter.name == :long_tailed_distrib && iterable_type == :column
        return true
    elseif linter.name == :circular_domain && iterable_type == :column
        return true
    elseif linter.name == :uncommon_list_lengths && iterable_type == :column
        return true
    else
        return false
    end
end


function version()
    ver = v"0.1.0"
end

end  # module
