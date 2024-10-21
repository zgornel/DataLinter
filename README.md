# DataLinter

A data linter written in Julia at the Vrije Universiteit Brussel.

[![Build Status](https://github.com/zgornel/DataLinter/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/zgornel/DataLinter/actions/workflows/CI.yml?query=branch%3Amaster)
[![License](http://img.shields.io/badge/license-GPL-brightgreen.svg?style=flat)](LICENSE.md)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/DataLinter/dev)


## Installation

The installation can be done by manually by cloning the repository or installing it through the julia `REPL`.

The Docker image can be installed with `docker pull ghcr.io/zgornel/datalinter-compiled:latest`. A sample timed run on the `churn.csv` dataset would require:
```
$ time docker run -it --rm --volume=.:/tmp \
    ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter /tmp/_data/churn.csv \
            --kb-path /tmp/knowledge/linting.toml \
            --log-level warn
```

## License

This code has an GPL license and therefore it is free as beer.


## Reporting Bugs

Please [file an issue](https://github.com/zgornel/DataLinter/issues/new) to report a bug or request a feature.


## References

[1] https://en.wikipedia.org/wiki/Lint_(software)

The initial version of DataLinter is inspired by [this work](https://github.com/brain-research/data-linter) written by Google brain research.
