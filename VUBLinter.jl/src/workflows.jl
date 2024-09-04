function cli_linting_workflow(filepath, kbpath, args...)
    kb = VUBLinter.kb_load(kbpath)
    buf =stdout
    ctx = VUBLinter.DataInterface.build_data_context(filepath)
    lintout = lint(ctx, kb, buffer=buf, show_stats=true, show_passing=false, show_na=false);
end
