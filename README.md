# `data | linter`

Linting library and tools for machine learning, statistical modelling, data, code.

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Latest Release](https://img.shields.io/github/v/release/zgornel/DataLinter?label=release)](https://github.com/zgornel/DataLinter/releases)
[![Tests](https://github.com/zgornel/DataLinter/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/zgornel/DataLinter/actions/workflows/test.yml?query=branch%3Amaster)
[![Build Status](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/zgornel/DataLinter/actions/workflows/ci.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/gh/zgornel/DataLinter/graph/badge.svg?token=GWKJKBZ5FB)](https://codecov.io/gh/zgornel/DataLinter)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://zgornel.github.io/DataLinter/dev)

![til](./gifs/cli.gif)

## Table of Contents
- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Integrations](#integrations)
- [Lint Catalog](#lint-catalog)
- [License](#license)
- [Contributing](#contributing)
- [References](#references)
- [Acknowledgements](#acknowledgements)

## Introduction

**DataLinter** is a library for contextual linting of data and code. Its development started by rewriting Google's [data linter](https://github.com/brain-research/data-linter), in [Julia](https://julialang.org/). The aim of the redesign was to provide a richer and faster experience while also providing the baseline benefits outlined in the original [paper](http://learningsys.org/nips17/assets/papers/paper_19.pdf). **DataLinter** adds on top support for data *contexts*, such as code snippets or information about the type of analysis, which can lead to the detection of more complex, conceptual issues relating to data and code quality.

### Key Features
- 23 [data+code linters](https://zgornel.github.io/DataLinter/dev/linters_config/) (including the [Google linters](https://github.com/brain-research/data-linter))
- Zero-config CLI and HTTP server modes
- Production-ready Docker image and GitHub Actions integration
- Flexible code querying through [ParSitter.jl](https://github.com/zgornel/ParSitter.jl)
- First-class R language support by [tree-sitter](https://tree-sitter.github.io/tree-sitter/)-based code parsing
- Fully customizable rule engine (see [configuration docs](https://zgornel.github.io/DataLinter/dev))

## Quick Start
Try it in seconds with Docker (no installation required):

```bash
# Lint a dataset (from the root directory of the repository)
datalinter ./test/data/imbalanced_data.csv \
    --code-path ./test/code/r_snippet_imbalanced.r \
    --config-path ./config/r_modelling_config.toml \
    --log-level error

# Or run the server for HTTP API use
./datalinterserver \
    -p 10000 \
    --config-path ./config/r_modelling_config.toml \
    --log-level debug
```

## Installation

### Docker image

The latest Docker image can be downloaded with
```bash
docker pull ghcr.io/zgornel/datalinter-compiled:latest
```
Specific versions are also tagged and **accessible** with (example for `v0.1.2`)
```bash
docker pull ghcr.io/zgornel/datalinter-compiled:v0.1.2
```

### Pre-compiled binaries (Linux x86-64)
Download the latest `datalinter-compiled-binary.zip` from the [Releases](https://github.com/zgornel/DataLinter/releases) page. Contains both CLI and server binaries.

> Note: Windows and macOS users should use Docker or install via Julia.

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
 - [Jupyter Notebooks](https://github.com/zgornel/Ipython-datalinter)
 - [Github Actions](https://github.com/OxoaResearch/datalinter-github-action)
 - Gitlab CI *(upcoming)*
 - VS Code *(upcoming)*

## Lint Catalog

**DataLinter** ships with **23 built-in linters**. Description available [here](https://zgornel.github.io/DataLinter/dev/linters_config/).

## License

This code has an MIT license.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) on how to contribute.

To report a bug or request a feature, please [file an issue](https://github.com/zgornel/DataLinter/issues/new).

Recent changes can be found in [CHANGELOG.md](CHANGELOG.md).

## References

[1] https://en.wikipedia.org/wiki/Lint_(software)

[2] N. Hynes, D. Sculley, M. Terry "The data linter: Lightweight, automated sanity checking for ml data sets", NIPS MLSys Workshop, 2017; [paper](http://learningsys.org/nips17/assets/papers/paper_19.pdf)

[3] The [data-linter](https://github.com/brain-research/data-linter) code repository

## Acknowledgements

The initial version of **DataLinter** was fully inspired by [this work](https://github.com/brain-research/data-linter) written by Google brain research.
