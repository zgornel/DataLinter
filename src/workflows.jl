"""
Basic flow for running the linter in a command line interface environment
such as a Unix shell.
"""
function cli_linting_workflow(
        filepath,
        codepath,
        kbpath,
        configpath;
        buffer = stdout,
        show_stats = true,
        show_passing = false,
        show_na = false,
        progress = false,
        linters = ["all"]
    )
    kb = DataLinter.kb_load(kbpath)
    code = try
        if !isempty(codepath)
            read(codepath, String)
        else
            ""
        end
    catch e
        @debug "Could not read code file @$codepath. Code-based linters will not work."
        ""
    end
    @info code
    ctx = DataLinter.DataInterface.build_data_context(filepath, code)
    config = DataLinter.Configuration.load_config(configpath)
    lintout = lint(ctx, kb; config, progress, linters)
    return process_output(lintout; buffer, show_passing, show_stats, show_na)
end
