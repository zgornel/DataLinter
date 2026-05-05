# `data | linter`

Linting library and tools for machine learning, statistical modelling, data, code.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Tests](https://github.com/zgornel/DataLinter/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/zgornel/DataLinter/actions/workflows/test.yml?query=branch%3Amaster)
[![Build Status](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/gh/zgornel/DataLinter/graph/badge.svg?token=GWKJKBZ5FB)](https://codecov.io/gh/zgornel/DataLinter)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/DataLinter/dev)

![til](./gifs/cli.gif)


## Installation

### Docker image

The latest Docker image can be downloaded with
```bash
docker pull ghcr.io/zgornel/datalinter-compiled:latest`
```

For specific versions, use
```bash
docker pull ghcr.io/zgornel/datalinter-compiled:v0.x.y`
```

### Binaries

The cli and server binaries (linux-x86-64) can be downloaded from the [releases](https://github.com/zgornel/DataLinter/releases) page. Each release contains an  *Assets* section with the binaries as `datalinter-compiled-binary.zip`.


### Julia

Installation can be performed also from the Julia REPL with
```julia
using Pkg; Pkg.add(url="https://github.com/zgornel/DataLinter")
```

## Configuration

Check out the [documentation](https://zgornel.github.io/DataLinter/dev) for information on configuring, running and integrating the linters.

## Integrations

Available integrations:
 - [RStudio](https://github.com/zgornel/Rstudio-Addin-DataLinter)
 - [Jupyter Notebooks](https://github.com/zgornel/Ipython-datalinter).
 - [Github Actions](https://github.com/OxoaResearch/datalinter-github-action)
 - Gitlab CI **(upcoming)**
 - Visual Studio Code **(upcoming)**

## Lint Catalog

DataLinter ships with **23 built-in linters**. Description available [here](https://zgornel.github.io/DataLinter/dev/linters_config/).


## License

This code has an MIT license.


## Reporting Bugs

Please [file an issue](https://github.com/zgornel/DataLinter/issues/new) to report a bug or request a feature.


## References

[1] https://en.wikipedia.org/wiki/Lint_(software)

[2] N. Hynes, D. Sculley, M. Terry "The data linter: Lightweight, automated sanity checking for ml data sets", NIPS MLSys Workshop, 2017; [paper](http://learningsys.org/nips17/assets/papers/paper_19.pdf)

[3] The [data-linter](https://github.com/brain-research/data-linter) code repository


## Acknowledgements

The initial version of DataLinter was fully inspired by [this work](https://github.com/brain-research/data-linter) written by Google brain research.
