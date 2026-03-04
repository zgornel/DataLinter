# Usage examples

There are two tools through which linting can be done, both available in the Docker container:
 - `datalinter`, a command-line (CLI) tool, best suited for linting data outside an experimental environment. It builds its linting context through the configuration file and command line arguments.
 - `datalinterserver`, a HTTP server to which one can easily connect with a client. The server builds the context from configuration file and data, code provided in HTTP requests. It is best suited for online and interactive workflows, where code is readily available with the data to be linted.


## Quick start

### Testing the Docker image
The Docker image contains compiled versions of the CLI utility and server. To test that everything works, run:
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

The commands are meant to show the help of the two executables and exit.

> Note: Before running the linter, make sure that the Docker container has mapped all the relevant directories.

### Docker image folders, default configs
Currently, in the root directory of the `datalinter-compiled` Docker image, the following empty directories are available for mapping:
 - `/_data` - for mapping data folders
 - `/_config` - for mapping folders with multiple configuration files
 - `/output` - where outputs may be written
 - `/workspace` and `/tmp` generic folder for other mappings

To modify the structure, check out [the Dockerfile](https://github.com/zgornel/DataLinter/blob/master/docker/Dockerfile.datalinter-compiled.alpine) of the image. The directories are which are available inside the container should be easy to see and modify. Currently, these are the ones created with the `mkdir -p` command.

Inside the Docker image, the default configuration files are available in `/datalinter/config`. Running
```
$ docker run -it --rm ghcr.io/zgornel/datalinter-compiled:latest ls -l /datalinter/config
```
outputs
```
total 24
-rw-r--r--    1 root     root          4797 Feb 19 11:14 default.toml
-rw-r--r--    1 root     root          4901 Feb 19 11:14 imbalanced_data.toml
-rw-r--r--    1 root     root          4392 Feb 19 11:14 r_modelling_config.toml
```

## CLI-based linting

The CLI-based linter is useful for one-time linting, as is the case in CI pipelines. Contexts can be described easily with simple options i.e. type of experiment, target columns, data columns in the configuration file and also by providing a path to a code snippet relevant to the data. To lint a test dataset with no context, run the following command in the root of the repository:
```
$ docker run -it --rm \
    --volume=./test/data:/_data \
    --volume=./config/:/_config \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter \
            /_data/data.csv \
            --config-path /_config/default.toml \
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
```

The following lint uses a configuration file where the some context is provided as well in the config:
```
$ time docker run -it --rm \
    --volume=./test/data:/_data \
    --volume=./config:/_config \
        ghcr.io/zgornel/datalinter-compiled:latest \
            /datalinter/bin/datalinter /_data/imbalanced_data.csv \
            --config-path /_config/imbalanced_data.toml \
            --log-level error
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
```

Finally, one can provide code to the linter through the `--code-path` option:
```
time docker run -it --rm \
    --volume=./test/code:/tmp \
    --volume=./test/data:/_data \
    --volume=./config/:/_config \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter \
            /_data/imbalanced_data.csv \
            --code-path /tmp/r_snippet_imbalanced.r \
            --config-path /_config/r_modelling_config.toml \
            --print-exceptions \
            --log-level error
```
which outputs:
```
! warning       (large_outliers)        column: col4         the values of 'column: col4' contain large outliers
! warning       (int_as_float)          column: col4         the values of 'column: col4' are floating point but can be integers
! warning       (R_glmmTMB_target_variable)     dataset              Imbalanced dependent variable (glmmTMB)
3 issues found from 11 linters applied (7 OK, 4 N/A) .
```

## Server-based linting

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
--- Linting output (HTTP Status: 200):
• n/a           (imbalanced_target_variable)    dataset              linter not applicable (or failed) for 'dataset'
• experimental  (R_glmmTMB_target_variable)     dataset              Imbalanced dependent variable (glmmTMB)
• experimental  (R_glmmTMB_binomial_modelling)  dataset              Incorrect binomial data modelling (glmmTMB)
1 issues found from 3 linters applied (2 OK, 1 N/A) .
```

### Server HTTP API

The HTTP server expects the following requests:
 - `GET` at `/api/kill` which stops the server
 - `POST` at `/api/lint` which triggers a linting request. This requires a JSON body with data, code and options specified.

For lint requests, a representative example of the `body` of the request is shown below:
```
{
  "options" : {
         "show_na" : false,
         "show_passing" : false,
         "show_stats" : true
         },
  "context" : {
         "data_header" : true,
         "data_delim" : ",",
         "data_type" : "dataset",
         "data" : "a,b,c\n1,2,3\n4,5,6",
         "code" : "",
         "linters" : ["all"]
         }
}
```
The available fields are:
 - `show_na`, a boolean that enables to show linters that were not available. Default is `false`
 - `show_passing` boolean that enables to show linters that raised no issuesa. Default is `false`
 - `show_passing` boolean that enables to show statistics. Default is `false`
 - `data_header` boolean that indicates whether the data has a header
 - `data_delim` string that sets the data delimiter
 - `data_type` string that indicates data source: if `"dataset"`, the `"data"` field contains the data; if `"filepath"`, the `"data"` field is a path to the data file
 - `data` a string that can contain either a path to the data or a string with the raw data, depending on the value of `data_type` whether the data has a header
 - `code` a string which contains any relevant code
 - `linters` a list which selects linters. Available values are `"all"` for all linters, `"r"` for r linters, `"google"` for the Google linters and `"experimental"` for linters marked as experimental. The default is `"all"`.

The response is a HTTP message with the following JSON in the body:
```
{"linter_output" : "<Same linting output that gets printed at stdout...>"}
```

## Using the `datalinter.sh` script
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
