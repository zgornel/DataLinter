# DataLinter

A data linter written in Julia at the Vrije Universiteit Brussel.

[![Build Status](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml?query=branch%3Amaster)
[![License](http://img.shields.io/badge/license-GPL-brightgreen.svg?style=flat)](LICENSE.md)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/DataLinter/dev)


## Installation

The installation can be done by manually by cloning the repository or installing it through the julia `REPL`.

The Docker image can be installed with `docker pull ghcr.io/zgornel/datalinter-compiled:latest`.

Make sure that the Docker container has mapped all the relevant directories. Check out [the Dockerfile](https://github.com/zgornel/DataLinter/blob/master/docker/Dockerfile.datalinter-compiled.alpine) of the image to see what directories are available inside the container (created with the `mkdir -p` commands).

A sample timed run on the `churn.csv` dataset would look like:
```
$ time docker run -it --rm \
    --volume=<FULL_PATH_TO_DATA_DIR>:/_data \
    --volume=<FULL_PATH_TO_CONFIG_DIR>:/_config \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter /_data/churn.csv \
            --config-path /_config/config.toml \
            --kb-path /datalinter/knowledge/linting.toml \
            --log-level warn
```

## License

This code has an GPL license and therefore it is free as beer.


## Reporting Bugs

Please [file an issue](https://github.com/zgornel/DataLinter/issues/new) to report a bug or request a feature.


## References

[1] https://en.wikipedia.org/wiki/Lint_(software)
[2] Data linter by Google: https://github.com/brain-research/data-linter

## Acknowledgements
The initial version of DataLinter was fully inspired by [this work](https://github.com/brain-research/data-linter) written by Google brain research.
