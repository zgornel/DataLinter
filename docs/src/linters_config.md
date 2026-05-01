## Full lint catalog & Configuration guide

DataLinter ships with **23 built-in linters** divided into two families:

- **Data-only linters** – work on any tabular dataset, regardless of modeling language.
- **R-language specific linters** – understand R modeling functions (`lm`, `glm`, `glmmTMB`, …) and their statistical assumptions.

Linters are **disabled by default**. You enable them in a `config.toml` configuration file which contains three sections:
 - `experiment` contains general context about the experiment
 - `linters` allows to enable or disable explicitly linters; linters are enabled in this section
 - `parameters` where individual linter parameters can be set. The names of the parameters correspond to keyword arguments names in the functions implementing the linters.

### Quick Configuration Example

```toml
[experiment]
    name = "My R linear model"
    target_variable = 2  # column index of target variable in the dataset
[linters]
    # Enable only what you need
    # - code has to be R; checks for normality of columns
    large_outliers = true
    R_data_normally_distributed = true
[parameters]
    [parameters.R_data_normally_distributed]
        # threshold for normality tests; higher values correspond
        # to more strict normal distribution assumptions
        pvalue_threshold = 0.1
```
Full example configs are in the [config](https://github.com/zgornel/DataLinter/tree/master/config) folder.

### Data-only linters

|Linter|Description|Typical Context|Key Parameters (see config/)|
|------|-----------|---------------|----------------------------|
|`datetime_as_string`|Checks if dates are wrongly encoded as strings|Any tabular data|`match_perc`|
|`tokenizable_string`|Checks whether string values can be split into tokens|Text / categorical columns|`min_tokens`|
|`number_as_string`|Checks whether string column can be converted to numbers|Numeric data stored as text|`match_perc`|
|`zipcodes_as_values`|Checks whether values correspond to Zip/postal codes|Location columns|`zipcodes`, `match_perc`|
|`large_outliers`|Detects large outliers (Tukey’s fences)|Numerical features|`tukey_fences_k`|
|`int_as_float`|Checks floating-point values that could be integers|Numerical columns|-|
|`enum_detector`|Detects columns that are actually enumerations|Categorical data|`distinct_ratio`, `distinct_max_limit`|
|`uncommon_list_lengths`|Checks columns containing lists of varying lengths|List / nested data|-|
|`duplicate_examples`|Finds identical duplicate rows|Any dataset|-|
|`empty_example`|Detects completely empty rows|Any dataset|-|
|`uncommon_signs`|Flags numerical columns with very few opposite signs|Signed numeric data|-|
|`long_tailed_distrib`|Detects long-tailed distributions|Numerical features|`drop_proportion`, `zscore_multiplier`|
|`circular_domain`|Identifies circular data (hours| degrees| etc.)|Angular / periodic data|-|
|`many_missing_values`|Warns about columns with high missingness|Any dataset|`threshold`|
|`negative_values`|Checks for negative values in a column|Count / amount columns|-|
|`imbalanced_target_variable`|Detects imbalanced target classes|Classification targets|`threshold`|
|`vif_colinearity`|Detects high multicolinearity using VIF |Numerical data|`vif_threshold`|
|`cnc_colinearity`|Detects high multicolinearity using condition number analysis |Numerical data|`cnc_threshold`|

### R language specific linters
|Linter|Description|Model Context|Key Parameters (see config/)|
|------|-----------|-------------|----------------------------|
|`R_imbalanced_target_variable`|Checks target variable imbalance in any regression function with a formula|Regression algorithms|`threshold`|
|`R_glmmTMB_binomial_modelling`|Validates link parameter for binomial family in `glmmTMB`|glmmTMB binomial|`acceptable_link_values`|
|`R_data_normally_distributed`|Checks normality of non-binary numeric columns or target in models|Regression methods|`pvalue_threshold`, `algorithms`, `check_target`, `check_predictors`|
|`R_glm_binomial_modelling`|Checks normality of non-binary numeric columns in binomial glm|Logistic regression|`pvalue_threshold`|
|`R_colinearity_with_target`|Detects whether any predictor variable is highly colinear with the target|Regression algorithms|`threshold`, `algorithms`|
