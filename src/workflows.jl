function cli_linting_workflow(filepath,
                              kbpath;
                              buffer=stdout,
                              show_stats=true,
                              show_passing=false,
                              show_na=false)
    kb = DataLinter.kb_load(kbpath)
    ctx = DataLinter.DataInterface.build_data_context(filepath)
    lintout = lint(ctx, kb; buffer, show_stats, show_passing, show_na);
end
