# Usage examples

!!! note

    Results from running the commands below may vary depending on the current state of the configuration files. Take the outputs are representative samples of the expected output only.

There are two tools through which linting can be done,
 - `datalinter`, a command-line (CLI) tool, best suited for linting data outside an experimental environment. It builds its linting context through the configuration file and command line arguments.
 - `datalinterserver`, a HTTP server to which one can easily connect with a client. The server builds the context from configuration file and data, code provided in HTTP requests. It is best suited for online and interactive workflows, where code is readily available with the data to be linted.

These can be ran with
 - Docker commands `docker run ...`
 - the `datalinter` and `datalinterserver` Julia scripts in the root repository (automatically build and run Docker commands)
 - compiled binaries (Linux-only) downloadable from the [Releases](https://github.com/zgornel/DataLinter/releases) page.

## Quick start

All the examples below use code and data available in the repository. These are located in
 - [`test/data`](https://github.com/zgornel/DataLinter/tree/master/test/data) for datasets; these are `.csv` files
 - [`test/code`](https://github.com/zgornel/DataLinter/tree/master/test/code) for code snippets
 - [`config/`](https://github.com/zgornel/DataLinter/tree/master/config) for configuration files


### Testing the Docker image
The Docker image contains compiled versions of the CLI utility and server. To test that everything works, run:
```bash
$ docker run -it --rm \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter --help
```
and
```bash
$ docker run -it --rm \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinterserver/datalinterserver --help
```
respectively.

The commands are meant to show the help of the two executables and exit. Before running the linter, make sure that the Docker container has mapped all the relevant directories.

!!! info

    The `datalinter` and `datalinterserver` scripts automatically map the folders by detecting the
    directories in which data, code and configs reside.

### Docker image folders, default configs

Currently, in the root directory of the `datalinter-compiled` Docker image, the following empty directories are available for mapping:
 - `/_data` - for mapping data folders
 - `/_code` - for mapping code folders
 - `/_config` - for mapping folders with multiple configuration files
 - `/output` - where outputs may be written
 - `/workspace` and `/tmp` generic folder for other mappings

Inside the Docker image, the default configuration files are available in `/datalinter/config`. Running
```
$ docker run -it --rm ghcr.io/zgornel/datalinter-compiled:latest ls -l /datalinter/config
```
outputs
```
total 24
-rw-r--r-- 1 root root 5016 May 12 07:38 default.toml
-rw-r--r-- 1 root root 5082 May 12 07:38 imbalanced_data.toml
-rw-r--r-- 1 root root 5760 May 12 07:38 r_modelling_config.toml
```

> To use custom i.e. local configuration files, one should map the local configuration directory to one in the Docker image, `_config` for example. Therefore, when running the `docker run` command one should have the mapping as `--volume=<PATH/TO/LOCAL/CONFIG>:/_config`.

## `datalinter` CLI-based linting

The CLI-based linter is useful for one-time linting, as is the case in CI pipelines. Contexts can be described easily with simple options i.e. type of experiment, target columns, data columns in the configuration file and also by providing a path to a code snippet relevant to the data.

### Input arguments

Positional arguments:
 - `input(s)`, file(s) to be linted

Optional arguments:
 - `--code-path`, path to code file (default: `""`)
 - `--kb-path`, path for the knowledge base file (default: `""`) (**not used**)
 - `--config-path`, path for the `.toml` configuration file (default: `""`)
 - `--output-type`, output type `"text"` or `"json"` (default: `"text"`)
 - `--log-level`, logging level (default: `"error"`)
 - `--linters`, list of linter groups to use. Avaliable: `"google"`, `"extended"`, `"r"`, `"all"` (default: `"all"`)
 - `-v`, `--version`, print version
 - `--progress`, show progress
 - `-t`, `--timed`, print timings
 - `--print-exceptions`, print encountered exceptions while linting
 - `-h`, `--help`, show help message and exit

### Linting with no context
The example below lints a dataset with no context. The command can be run in the root of the repository:
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
× important     (empty_example)                 row: 10              the example at 'row: 10' looks empty
× important     (empty_example)                 row: 11              the example at 'row: 11' looks empty
! warning       (large_outliers)                column: x1           the values of 'column: x1' contain large outliers
! warning       (int_as_float)                  column: x4           the values of 'column: x4' are floating point but can be integers
! warning       (vif_colinearity)               dataset              High multicolinearity detected in dataset using VIF
• info          (tokenizable_string)            column: x6           the values of 'column: x6' could be tokenizable i.e. contain spaces
• info          (tokenizable_string)            column: x8           the values of 'column: x8' could be tokenizable i.e. contain spaces
• info          (enum_detector)                 column: x5           just a few distinct values in 'column: x5', it could be an enum
• info          (enum_detector)                 column: x8           just a few distinct values in 'column: x8', it could be an enum
• info          (enum_detector)                 column: x4           just a few distinct values in 'column: x4', it could be an enum
• info          (uncommon_signs)                column: x1           uncommon signs (+/-/NaN/0) present in 'column: x1'
• info          (long_tailed_distrib)           column: x1           the distribution for 'column: x1' has 'long tails'
• info          (negative_values)               column: x1           found negative values in 'column: x1'
```

### Linting with `config.toml` context

The command below uses a configuration file where the some context is provided:
```bash
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
! warning       (large_outliers)                column: col4         the values of 'column: col4' contain large outliers
! warning       (int_as_float)                  column: col4         the values of 'column: col4' are floating point but can be integers
! warning       (imbalanced_target_variable)    dataset              Imbalanced target column in 'dataset' for values=Any[0.0]
• info          (enum_detector)                 column: col4         just a few distinct values in 'column: col4', it could be an enum
• info          (uncommon_signs)                column: col4         uncommon signs (+/-/NaN/0) present in 'column: col4'
• info          (long_tailed_distrib)           column: col4         the distribution for 'column: col4' has 'long tails'
docker run -it --rm --volume=./test/data:/_data --volume=./config:/_config     0.01s user 0.02s system 0% cpu 3.130 total
```

### Linting with code context

Finally, one can provide code to the linter through the `--code-path` option. The command below will send the following code
```r
library(glmmTMB)
data_path <- "~/projects/DataLinter/test/data/imbalanced_data.csv"
out1 <- read.csv(data_path, header=TRUE)
m2 <- glmmTMB(col4 ~ col1 + col2 + col3,
              data = out1,
              family=binomial(link="linear"))
```
to the linter in addition to the data:
```bash
$ time docker run -it --rm \
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
! warning       (int_as_float)          column: col4         the values of 'column: col4' are floating point but can be integers
! warning       (vif_colinearity)       dataset              High multicolinearity detected in dataset using VIF
! warning       (R_imbalanced_target_variable)  dataset              Imbalanced distribution of target variable values
• info          (R_data_normally_distributed)   dataset              Non-normal variables present
```

## `datalinterserver` HTTP-based linting

The server version of the linter is useful for integration with editors and other third party apps that can interactively communicate by sending data and receiving outputs from a remote linter.

### Input arguments

Optional arguments:
 - `-p`, `--http-port`, HTTP port (default: `10000`)
 - `-i`, `--http-ip`, HTTP IP address (default: `"127.0.0.1"`)
 - `--config-path`, path for the `.toml` configuration file (default: `""`)
 - `--kb-path`, path for the knowledge base file (default: `""`) (**not used**)
 - `--priming-code-path`, priming code file path (default: "")
 - `--priming-data-path`, priming data file path (default: "")
 - `--log-level`, logging level (default: `"error"`)
 - `-h`, `--help`, show help over parameters

!!! note

    For faster first query response time, one can use the code and data priming options.
    This will lint the data and code at the paths provided through
    `--priming-data-path` and `--priming-code-path` respectively.

### Running the server

To start the linting server with one of the default configurations and listen on address `0.0.0.0` and port `10000` one can run
```bash
$ docker run -it --rm -p10000:10000 \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinterserver/bin/datalinterserver \
            -i 0.0.0.0 \
            -p 10000 \
            --config-path /datalinter/config/r_modelling_config.toml \
            --log-level info
```
Upon starting, the server outputs:
```
[ Info: • Data linting server online @0.0.0.0:10000...
[ Info: Listening on: 0.0.0.0:10000, thread id: 1
```

The server accepts HTTP requests with a specific JSON payload containing data or, data and code. Upon receiving a request, it will try to run the linter and return a JSON with the output. A client script can be found in `scripts/client.jl`. The following command sets up a temporary environment for the script to run:
```bash
$ julia --project=@datalinter -e 'using Pkg; Pkg.add(["HTTP", "JSON", "DelimitedFiles"])'
```
Running the client script with data and code arguments
```bash
$ julia --project=@datalinter ./scripts/client.jl ./data/imbalanced_data.csv ./test/code/r_snippet_binomial.r
```
outputs:
```
--- Linting output (HTTP Status: 200):
! warning       (int_as_float)          column: col4         the values of 'column: col4' are floating point but can be integers
! warning       (vif_colinearity)       dataset              High multicolinearity detected in dataset using VIF
! warning       (R_imbalanced_target_variable)  dataset              Imbalanced distribution of target variable values
! warning       (R_glmmTMB_binomial_modelling)  dataset              Incorrect binomial data modelling (glmmTMB)
• info          (R_data_normally_distributed)   dataset              Non-normal variables present
```

### Send data using `wget` and `jq`

Data can also be sent to the linting server with generic tools. For example, using `wget` and `jq`. The following command sends reads data and code, interpolates them in a JSON string and sends it to the server.
```bash
$ wget -O- --post-data="{\"linter_input\" : {\"context\" : {\"data\":$(jq -n --rawfile zz ./test/data/imbalanced_data.csv '$zz'), \"data_type\" : \"dataset\", \"linters\" : [\"all\"], \"data_delim\" : \",\", \"data_header\" : true, \"code\" :$(jq -n --rawfile zz ./test/code/r_snippet_imbalanced.r '$zz')}, \"options\" : {\"show_stats\":true, \"show_passing\":false, \"show_na\":false}}}" \
  --header='Content-Type:application/json' \
  'http://0.0.0.0:10000/api/lint'
```
Alternatively, the server supports sending only the data file path
```bash
wget -O- --post-data="{\"linter_input\" : {\"context\" : {\"data\":\"./test/data/imbalanced_data.csv\", \"data_type\" : \"filepath\", \"linters\" : [\"all\"], \"data_delim\" : \",\", \"data_header\" : true, \"code\" : $(jq -n --rawfile codevar ./test/code/r_snippet_imbalanced.r '$codevar')}, \"options\" : {\"show_stats\":true, \"show_passing\":false, \"show_na\":false}}}" --header='Content-Type:application/json' 'http://0.0.0.0:10000/api/lint' && \
```

To stop the server remotely, run
```bash
$ wget -O- 'http://0.0.0.0:10000/api/kill'
```

### Server HTTP API

The HTTP server expects the following requests:
 - `GET` at `/api/kill` which stops the server
 - `POST` at `/api/lint` which triggers a linting request. This requires a JSON body with data, code and options specified.

The server will return a the following response status codes:
 - `200` request was done (either linting or killing the server)
 - `400` linting encountered an error (i.e. malformed request)
 - `501` requested endpoint is not used.

For lint requests, a representative example of the `body` of the request is shown below:
```json
"linter_input": {
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
 - `show_passing` boolean that enables to show linters that raised no issues. Default is `false`
 - `show_passing` boolean that enables to show statistics. Default is `false`
 - `data_header` boolean that indicates whether the data has a header
 - `data_delim` string that sets the data delimiter
 - `data_type` string that indicates data source: if `"dataset"`, the `"data"` field contains the data; if `"filepath"`, the `"data"` field is a path to the data file
 - `data` a string that can contain either a path to the data or a string with the raw data, depending on the value of `data_type` whether the data has a header
 - `code` a string which contains any relevant code
 - `linters` a list which selects linters. Available values are `"all"` for all linters, `"r"` for r linters, `"google"` for the Google linters and `"extended"` for new data-only linters. The default is `"all"`.

The response is a HTTP message with the following JSON in the body:
```
{"linter_output" : "<Same linting output that gets printed at stdout...>"}
```

## Running in the Julia REPL

The following example represents the basic workflow behind linting:
 - load a configuration file
 - build context out of data and code contents
 - apply the linter and print the output.

```@example
const PROJECT_PATH = joinpath(abspath(dirname(@__FILE__)), "..", "..")
using DataLinter

kb = nothing
configpath = joinpath(PROJECT_PATH, "config", "r_modelling_config.toml")
datapath = joinpath(PROJECT_PATH, "test", "data", "imbalanced_data.csv")
codepath = joinpath(PROJECT_PATH, "test", "code", "r_snippet_imbalanced.r")

config = DataLinter.LinterCore.load_config(configpath)
ctx = DataLinter.DataInterface.build_data_context(datapath, read(codepath, String))
@time out = DataLinter.lint(ctx, kb; config = config);
DataLinter.process_output(out; show_stats = true)
```

## Using the `datalinter` script
> Note: This option does not support the specification of a config file or code.

The linter can also be run quickly through the `datalinter` Julia script. To run in on the test dataset, one can do
 - Unix-like (Linux/macOS/Git Bash/WSL): `./datalinter path/to/yourfile.csv [extra flags...]`
 - Windows (PowerShell or cmd): `julia --startup-file=no datalinter "C:\path\to\yourfile.csv" [extra flags...]`

The script can be ran from any directory and accepts a single argument, the dataset that is to be linted.

## Additional resources

More working examples of running the Julia API of the linter can be found in the [`scripts/`](https://github.com/zgornel/DataLinter/tree/master/scripts) directory.
