# DataLinter

A data linter written in Julia at the Vrije Universiteit Brussel.

[![Build Status](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml?query=branch%3Amaster)
[![License](http://img.shields.io/badge/license-GPL-brightgreen.svg?style=flat)](LICENSE.md)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/DataLinter/dev)


## Installation

The recommended way to install `DataLinter` is to download the docker image:
```
$ docker pull ghcr.io/zgornel/datalinter-compiled:latest
```
This will download a Docker image with the compiled version of the data linter. For development, one can dowload the repository and build the Docker image separately if needed.

> Note: Before running the linter, make sure that the Docker container has mapped all the relevant directories. Check out [the Dockerfile](https://github.com/zgornel/DataLinter/blob/master/docker/Dockerfile.datalinter-compiled.alpine) of the image to see what directories are available inside the container (created with the `mkdir -p` commands).


## Running the linter

To perform a smaple run on the test dataset from the repository from inside the root of the repository:
```
$ time docker run -it --rm \
    --volume=./test/data:/_data \
    --volume=./config:/_config \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter /_data/data.csv \
            --config-path /_config/default.toml \
            --log-level warn
```

The output should look something like:
```
┌ Warning: Could not load KB@. Returning empty Dict().
└ @ DataLinter.KnowledgeBaseNative ~/.julia/packages/DataLinter/5mybQ/src/kb.jl:22
• info  (tokenizable_string)    column: x6           the values of 'column: x6' could be tokenizable i.e. contain spaces
• info  (tokenizable_string)    column: x8           the values of 'column: x8' could be tokenizable i.e. contain spaces
• info  (large_outliers)        column: x1           the values of 'column: x1' contain large outliers
! warn  (int_as_float)          column: x4           the values of 'column: x4' are floating point but can be integers
! warn  (enum_detector)         column: x5           just a few distinct values in 'column: x5', it could be an enum
! warn  (enum_detector)         column: x8           just a few distinct values in 'column: x8', it could be an enum
! warn  (enum_detector)         column: x4           just a few distinct values in 'column: x4', it could be an enum
! warn  (empty_example)         row: 10              the example at 'row: 10' looks empty
! warn  (empty_example)         row: 11              the example at 'row: 11' looks empty
! warn  (uncommon_signs)        column: x1           uncommon signs (+/-/NaN/0) present in 'column: x1'
! warn  (long_tailed_distrib)   column: x1           the distribution for 'column: x1' has 'long tails'
11 issues found from 14 linters applied (13 OK, 1 N/A) .
docker run -it --rm --volume=./test/data:/_data --volume=./config:/_config     0.02s user 0.01s system 0% cpu 4.197 total
```

### Using the script

The linter can be run quickly through the `datalinter.sh` shell script. To run in on the test dataset, one can do:
```
$ ./datalinter.sh ./test/data/data.csv
```
The script can be ran from any directory and accepts a single argument, the dataset that is to be linted.

## License

This code has an GPL license and therefore it is free as beer.


## Reporting Bugs

Please [file an issue](https://github.com/zgornel/DataLinter/issues/new) to report a bug or request a feature.


## References

[1] https://en.wikipedia.org/wiki/Lint_(software)

[2] A [data linter](https://github.com/brain-research/data-linter) written by Google

## Acknowledgements
The initial version of DataLinter was fully inspired by [this work](https://github.com/brain-research/data-linter) written by Google brain research.
