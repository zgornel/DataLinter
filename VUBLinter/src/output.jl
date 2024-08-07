module OutputInterface

import ..LinterCore: process_output

function process_output(lintout)
    for ((rule, v_name), result) in lintout
        if result == false
            @info("$(rule.message(v_name))")
        end
    end
    if all(v for ((_, _), v) in lintout)
        @info("No linting errors found.")
    end
end

end  # module
