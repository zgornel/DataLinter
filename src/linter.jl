@reexport module LinterCore
using Dates
using Tables
using REPL
using ProgressMeter
using ParSitter
export AbstractDataContext, lint, version, process_output


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
    requirements::Dict{String}
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
@Base.kwdef mutable struct LintingContext
    name::String = ""
    analysis_type::Union{Nothing, String} = nothing
    analysis_subtype::Union{Nothing, String} = nothing
    target_variable::Union{Nothing, Int, String} = nothing
    data_variables::Union{Nothing, Vector{Int}, Vector{String}} = nothing
    programming_language::Union{Nothing, String} = nothing
    parsing_data = nothing  #::Any
end


"Function that builds a `LintingContext` from code and code query"
function build_linting_context(code::String, linter::Linter)
    # Query helper functions
    __target_nodevalue(n) = strip(replace(n.content, r"[\s]"=>""))
    __query_nodevalue(n) = ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head,"@")[1]), n.head)
    __apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym="@").is_match || qn.head=="*"
    __capture_function(n) = (v=string(strip(replace(n.content, r"[\s]"=>""))), srow=n["srow"], erow=n["erow"], scol=n["scol"], ecol=n["ecol"])
    # Start parsing and query matching
    query = linter.query
    language = linter.programming_language
    if query !== nothing && language !== nothing
        try
            query_tree = ParSitter.build_tq_tree(query)
            code_struct = (ParSitter.Code(code), language)
            code_tree = ParSitter.build_xml_tree(
                            first(values(
                                ParSitter.parse(code_struct...))))
            query_results=ParSitter.query(code_tree.root,
                                          query_tree;
                                          match_type=:strict,
                                          target_tree_nodevalue=__target_nodevalue,
                                          query_tree_nodevalue=__query_nodevalue,
                                          capture_function=__capture_function,
                                          node_comparison_yields_true=__apply_regex_glob)
            filter!(first, query_results) # keep only matches
            if length(query_results) == 0
                return nothing
            elseif length(query_results) > 1
                @debug "Multiple query matches, query is not specific enough"
                return nothing
            else
                _, _parsed_data = first(query_results)
                code_ctx = LintingContext(name="Online Context [$(now())]")
                for (k, _captures) in _parsed_data
                    @assert length(_captures) == 1 "Multiple captures, query is not specific enough"
                    symb_key = Symbol(k)
                    if symb_key in fieldnames(typeof(code_ctx))
                        setfield!(code_ctx, symb_key, (first(_captures)).v)
                    end
                end
                isnothing(code_ctx.parsing_data) && setfield!(code_ctx, :parsing_data, query_results)
                return code_ctx
            end
        catch e
            @debug "Could not create linting context\n$e"
            nothing
        end
    end
    return nothing
end

"Function that builds a `LintingContext` from a linter configuration"
function build_linting_context(config)
    try
        return LintingContext(get_experiment_parameters(config)..., nothing)
    catch e
        @debug "Could not create linting context\n$e"
        return nothing
    end
end

build_linting_context(::Nothing, linter::Linter) = nothing
build_linting_context(::Nothing) = nothing

"""
    reconcile_contexts(code_ctx, config_ctx)

Function that reconciles contexts obtained from code and configuration `.toml` file.
The basic approach is to take all available data from `code_ctx` and when not available
fill in from `config_ctx`.
"""
function reconcile_contexts(code_ctx::LintingContext, config_ctx::LintingContext)
    r_ctx = LintingContext(name="")
    for field_key in fieldnames(typeof(r_ctx))
        _code_val = getfield(code_ctx, field_key)
        _config_val = getfield(config_ctx, field_key)
        if !isnothing(_code_val)
            setfield!(r_ctx, field_key, _code_val)
        elseif !isnothing(_config_val)
            setfield!(r_ctx, field_key, _config_val)
        else
            # do nothing
        end
    end
    return r_ctx
end

reconcile_contexts(code_ctx, ::Nothing) = code_ctx
reconcile_contexts(::Nothing, config_ctx) = config_ctx
reconcile_contexts(::Nothing, ::Nothing) = nothing


"""
    lint(data_ctx::AbstractDataContext, kb::Union{Nothing, AbstractKnowledgeBase}; config=nothing, debug=false, linters=["all"])

Main linting function. Lints the data provided by `data_ctx` using
knowledge from `kb`. A configuration for the available linters
can be provided in `config`. If `debug=true`, performance information
for each linter are shown. By default, all available linters will be used.
"""
function lint(data_ctx::AbstractDataContext,
              kb::Union{Nothing, AbstractKnowledgeBase};
              config=nothing,
              debug=false,
              progress=false,
              linters=["all"])
    # TODO: Improve the `lintout` structure to something more workable
    #       that includes timings, outputs, easy referencing i.e. Dict
    lintout = Vector{Pair{Tuple{Linter, String}, Union{Nothing, Bool}}}()
    datait = build_data_iterator(data_ctx)

    _progress = ProgressUnknown(desc="Linting...", spinner=true, color=:white, showspeed=true)
    _terminal = REPL.Terminals.TTYTerminal("", stdin, stdout, stderr)
    for linter in build_linters(kb, data_ctx; linters)
        if linter_is_enabled(config, linter)
            linter_kwargs = get_linter_kwargs(config, linter)  # this injects configuration parameters into linter functions
            # Build linting context:
            #  - from the context code (online workflow type)
            #  - from config (cli workflow type)
            code = get_context_code(data_ctx)
            linting_ctx = reconcile_contexts(
                            build_linting_context(code, linter),
                            build_linting_context(config))
            _t = @timed begin
                    # Apply linter:
                    #  - run linter function
                    #  - compare result with the one stored in closure for correctness
                    #  - if the result is false i.e. mismatch in values, linter fails (warning displayed)
                    #  - if the result is true i.e. expexted value returned, linter passes
                    # 1. Apply over column
                    if applicable(linter, linting_ctx, :column)
                        for (i, col) in enumerate(datait.column_iterator)
                            _name = columnname(datait, i)
                            _type = columntype(datait, i)
                            result = linter.correct_if(
                                        linter.f(_type, col, skipmissing(col), _name, linting_ctx; linter_kwargs...)
                                     )
                            push!(lintout, (linter, "column: $_name") => result)
                            progress && next!(_progress, spinner=SPINNER)
                        end
                    end
                    # 2. Apply over rows
                    if applicable(linter, linting_ctx, :row)
                        irow = 1
                        no_empty_rows = true
                        for row in datait.row_iterator
                            result = linter.correct_if(
                                        linter.f(row, linting_ctx; linter_kwargs...)
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
                    if applicable(linter, linting_ctx, :dataset)
                        result = linter.correct_if(
                                    linter.f(datait.tblref, linting_ctx; linter_kwargs...)
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


"""
Function that checks whether a linter is applicable or not. The logic is that
the iterable type must match and if `linter.linting_ctx==true` then a linting
context must exist, either specified in the config, through the presence of code
or both.
"""
function applicable(linter, linting_ctx, iterable_type)
    if get(linter.requirements, "iterable_type", nothing) == iterable_type &&
            ( (get(linter.requirements, "linting_ctx", nothing) == true && linting_ctx != nothing) ||
              (get(linter.requirements, "linting_ctx", nothing) == nothing) )
        return true
    else
        return false
    end
end


function version()
    ver = v"0.1.0"
end

end  # module
