function cli_linting_workflow(filepath,
                              kbpath,
                              configpath;
                              buffer=stdout,
                              show_stats=true,
                              show_passing=false,
                              show_na=false,
                              progress=false)
    kb = DataLinter.kb_load(kbpath)
    ctx = DataLinter.DataInterface.build_data_context(filepath)
    config = DataLinter.Configuration.load_config(configpath)
    lintout = lint(ctx, kb; config, progress);
    process_output(lintout; buffer, show_passing, show_stats, show_na)
end
