"""
Basic flow for running the linter in a command line interface environment
such as a Unix shell.
"""
function cli_linting_workflow(filepath,
                              kbpath,
                              configpath;
                              buffer=stdout,
                              show_stats=true,
                              show_passing=false,
                              show_na=false,
                              progress=false,
                              linters=["all"])
    kb = DataLinter.kb_load(kbpath)
    ctx = DataLinter.DataInterface.build_data_context(filepath)
    config = DataLinter.Configuration.load_config(configpath)
    lintout = lint(ctx, kb; config, progress, linters);
    process_output(lintout; buffer, show_passing, show_stats, show_na)
end


### """
### Basic flow for running the linter online, during experimental design such as a IPython notebook.
### """
### function online_linting_workflow(data=nothing,
###                                  code=nothing,
###                                  kb=nothing,
###                                  config=nothing;
###                                  show_stats=true,
###                                  show_passing=false,
###                                  show_na=false,
###                                  progress=true,
###                                  linters=["all"])
###     ctx = DataLinter.DataInterface.build_data_context(data, code)
###     lintout = lint(ctx, kb; config, progress, linters);
###     #TODO: return JSON or something usable in such circumstances
### end
