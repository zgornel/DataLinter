# Usage examples

There are two tools through which linting can be done, both available in the Docker container:
 - `datalinter`, a command-line (CLI) tool, best suited for linting data outside an experimental environment. It builds its linting context through the configuration file and command line arguments.
 - `datalinterserver`, a HTTP server to which one can easily connect with a client. The server builds the context from configuration file and data, code provided in HTTP requests. It is best suited for online and interactive workflows, where code is readily available with the data to be linted.


## Quick start

### Testing the utilities, containers
The Docker container contains compiled versions of the CLI utility and server. To test them, run
```
$ docker run -it --rm \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter --help
```
and
```
$ docker run -it --rm \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinterserver/datalinterserver --help
```
respectively.

> Note: Before running the linter, make sure that the Docker container has mapped all the relevant directories. Check out [the Dockerfile](https://github.com/zgornel/DataLinter/blob/master/docker/Dockerfile.datalinter-compiled.alpine) of the image to see what directories are available inside the container (created with the `mkdir -p` commands).

### Server-based linting
The first step is to start the linting server and provide a configuration file which is already present in the Docker image:
```
$ docker run -it --rm -p10000:10000\
    ghcr.io/zgornel/datalinter-compiled:latest\
        /datalinterserver/bin/datalinterserver\
            -i 0.0.0.0\
            -p 10000 \
            --config-path /datalinter/config/r_modelling_config.toml\
            --log-level debug
```

The next step is to install code dependencies for the client in a temporary Julia project:
```
$ julia --project=@datalinter -e 'using Pkg; Pkg.add(["HTTP", "JSON", "DelimitedFiles"])'
```

Finally, we need to run the client providing a dataset and a code snippet that uses the dataset. The following line assumes that the current directory is the root directory of the project as the paths to the client script, data and code are relative to it:
```
$ julia --project=@datalinter ./scripts/client.jl ./data/imbalanced_data.csv ./test/code/r_snippet_binomial.r
```

### CLI-based linting

The CLI-based linter is useful when linting data with no context or in contexts that can be described easily with simple options i.e. type of experiment, target columns, data columns. To lint a test dataset with no context, run the following command in the root of the repository:
```
$ time docker run -it --rm \
    --volume=./test/data:/_data \
    --volume=./config/:/_config \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter \
            /_data/data.csv \
            --config-path /_config/default.toml \
            --progress \
            --timed \
            --print-exceptions \
            --log-level error
```
The output should look something like:
```
× important     (empty_example)         row: 10              the example at 'row: 10' looks empty
× important     (empty_example)         row: 11              the example at 'row: 11' looks empty
! warning       (large_outliers)        column: x1           the values of 'column: x1' contain large outliers
! warning       (int_as_float)          column: x4           the values of 'column: x4' are floating point but can be integers
• info          (tokenizable_string)    column: x6           the values of 'column: x6' could be tokenizable i.e. contain spaces
• info          (tokenizable_string)    column: x8           the values of 'column: x8' could be tokenizable i.e. contain spaces
• info          (enum_detector)         column: x5           just a few distinct values in 'column: x5', it could be an enum
• info          (enum_detector)         column: x8           just a few distinct values in 'column: x8', it could be an enum
• info          (enum_detector)         column: x4           just a few distinct values in 'column: x4', it could be an enum
• info          (uncommon_signs)        column: x1           uncommon signs (+/-/NaN/0) present in 'column: x1'
• info          (long_tailed_distrib)   column: x1           the distribution for 'column: x1' has 'long tails'
• experimental  (negative_values)       column: x1           found values smaller than 0 in 'column: x1'
12 issues found from 15 linters applied (14 OK, 1 N/A) .
  Completed in 0.18922031 seconds, 9.90765380859375 MB allocated, 0.0% gc time
docker run -it --rm --volume=../test/data:/_data --volume=../config/:/_config  0.01s user 0.02s system 1% cpu 2.510 total
```

The following lint uses a configuration file where the some context is provided as well in the config:
```
$ time docker run -it --rm \
    --volume=./test/data:/_data \
    --volume=./config:/_config \
        ghcr.io/zgornel/datalinter-compiled:latest \
            /datalinter/bin/datalinter /_data/imbalanced_data.csv \
            --config-path /_config/imbalanced_data.toml \
            --log-level warn
```
which outputs,
```
! warning       (large_outliers)        column: col4         the values of 'column: col4' contain large outliers
! warning       (int_as_float)          column: col4         the values of 'column: col4' are floating point but can be integers
• info          (enum_detector)         column: col4         just a few distinct values in 'column: col4', it could be an enum
• info          (uncommon_signs)        column: col4         uncommon signs (+/-/NaN/0) present in 'column: col4'
• info          (long_tailed_distrib)   column: col4         the distribution for 'column: col4' has 'long tails'
• experimental  (imbalanced_target_variable)    dataset              Imbalanced target column in 'dataset'
6 issues found from 16 linters applied (11 OK, 5 N/A) .
docker run -it --rm --volume=../test/data:/_data --volume=../config:/_config   0.01s user 0.02s system 0% cpu 4.737 total
```

### Server-based linting

The server version of the linter is useful for integration with editors and other third party apps that can integrate outputs from a remote linter. To start the linting server and listen on address `0.0.0.0` and port `10000` one can run
```
$ docker run -it --rm -p10000:10000 \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinterserver/bin/datalinterserver \
            -i 0.0.0.0 \
			-p 10000 \
            --config-path /datalinter/config/r_modelling_config.toml \
            --log-level error
```
Upon starting, the server outputs:
```
 Warning: KB file not correctly specified, defaults will be used.
 └ @ datalinterserver /DataLinter/apps/datalinterserver/src/datalinterserver.jl:83
 [ Info: • Data linting server online @0.0.0.0:10000...
 [ Info: Listening on: 0.0.0.0:10000, thread id: 1
```
The server accepts HTTP requests with a specific JSON payload containing data or, data and code. Upon receiving a request, it will try to run the linter and return a JSON with the output. A client script can be found in `scripts/client.jl`. The following command sets up a temporary environment for the script to run:
```
$ julia --project=@datalinter -e 'using Pkg; Pkg.add(["HTTP", "JSON", "DelimitedFiles"])'
```
Running the client script with data and code arguments
```
$ julia --project=@datalinter ./scripts/client.jl ./data/imbalanced_data.csv ./test/code/r_snippet_binomial.r
```
outputs:
```
--- Code:
path <- "./data.csv"
out0 <- loaded_data(path)
out1 <- glmmTMB(col4 ~ col1 + col2 + col3,
                data = out0,
                family = binomial(link = "linear"))  # raises linter error

--- Linting output (HTTP Status: 200):
• n/a           (imbalanced_target_variable)    dataset              linter not applicable (or failed) for 'dataset'
• experimental  (R_glmmTMB_target_variable)     dataset              Imbalanced dependent variable (glmmTMB)
• experimental  (R_glmmTMB_binomial_modelling)  dataset              Incorrect binomial data modelling (glmmTMB)
1 issues found from 3 linters applied (2 OK, 1 N/A) .
```

### Using the `datalinter.sh` script
> Note: This option does not support the specification of a config file and will use the default linters and parameter values.

The linter can also be run quickly through the `datalinter.sh` shell script. To run in on the test dataset, one can do:
```
$ ./datalinter.sh ./test/data/data.csv
```
The script can be ran from any directory and accepts a single argument, the dataset that is to be linted.

## Running in the Julia REPL
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
