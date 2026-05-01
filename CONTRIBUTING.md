# Contributor Guide

Contributing to DataLinter is welcomed. Please read these guidelines before starting to work on this project.

## Reporting bugs

If you experience any crashes, errors or linting mistakes, file a bug report. The report should be a Github issue containing a minimal working example and details necessary to reproduce the issue. Please also add the julia version and DataLinter version in the issue as well.

## Feature requests

For any seemingly missing or incomplete features, file a bug report as well. It should be in the form of a Github issue as well containing a description of the feature, desired functioning and/or outcome as well as a minimal working example i.e. data, code.

## How to help
 - Trying it on your data, open an issue with what it missed.
 - Test the [RStudio add-in](https://github.com/zgornel/Rstudio-Addin-DataLinter) and open issues
 - Test the [Jupyter notebook magic](https://github.com/zgornel/Ipython-datalinter) and open issues

## Development guidelines

- In order to bring changes to the codebase, open a Github PR
- The code must be correct and tested
- A PR should contain a single self-contained logical enhancement to the codebase
- Squash commits in a PR.
- Outside package dependencies should be minimized
- If the code refers to a feature, it should be discussed in a PR before starting to code

## Formatting/style checks - run the runic linter
`./runrunic.jl` # Unix-like / Git Bash / WSL
`julia --startup-file=no --project=@runic runrunic.jl`   # Windows
