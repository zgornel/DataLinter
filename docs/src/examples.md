# Usage examples

## A simple tutorial
First, generate some random data:
```@repl index
using DataLinter

ncols, nrows = 3, 10
data = [rand(nrows) for _ in 1:ncols]
```
then, generate a context object:
```@repl index
ctx = DataLinter.build_data_context(data)
```
Context objects are the main linter inputs along with a knowledge base and the config.
!!! note

    At this point the knowledge base is not used.

```@repl index
kb = DataLinter.kb_load("")         # raises Warning
lintout = DataLinter.LinterCore.lint(ctx, kb)
lintout = DataLinter.LinterCore.lint(ctx, nothing)  # also works
```

Lastly, one can print output of activate linters i.e. the ones that found problems in the data.
```@repl index
DataLinter.process_output(lintout)
```
