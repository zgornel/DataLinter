module OutputHTML

using Tables, SummaryTables

import ..OutputInterface: HTMLOutputType, WARN_LEVEL_TO_NUM,
    get_status_string, get_linter_message
import ..LinterCore: Linter, process_output,
    AbstractCheck, PassedCheck, FailedCheck, NotAvailableCheck

function process_output(
        lintout,
        ::Type{<:HTMLOutputType};
        buffer = stdout,
        show_passing = false,
        show_na = false,
        show_stats = false,
        kwargs...
    )
    sorted_out = sort(lintout, by = l -> get(WARN_LEVEL_TO_NUM, (l[1][1]).warn_level, 0), rev = true)
    data = []
    for ((linter, loc_name), result) in sorted_out
        if !(result isa NotAvailableCheck)
            if result isa FailedCheck
                push!(data, _make_result_nt(linter, result, loc_name))
            elseif show_passing
                push!(data, _make_result_nt(linter, result, loc_name))
            end
        else
            if show_na
                push!(data, _make_result_nt(linter, result, loc_name))
            end
        end
    end
    tbl = simple_table(
        Tables.columntable(data),
        [
            :name => "Linter name",
            :warn_level => "Warning Level",
            :location => "Location",
            :description => "Description",
            :message => "Message",
            :status => "Status",
        ],
    )
    seekstart(buffer)
    show(buffer, MIME"text/html"(), tbl)
    return nothing
end

_make_result_nt(linter, result, loc_name) = begin
    return (
        name = string(linter.name),
        warn_level = linter.warn_level,
        location = loc_name,
        description = linter.description,
        message = get_linter_message(linter, result, loc_name),
        status = get_status_string(result),
    )
end


end  # module
