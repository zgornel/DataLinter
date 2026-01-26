# Linters and configuration

## The configuration file
The linters can be configured through a `.toml` configuration file which contains three sections:
 - `experiment` contains general context about the experiment
 - `linters` allows to enable or disable explicitly linters; linters are **disabled** by default if not enabled in this section
 - `parameters` where individual linter parameters can be set. The names of the parameters correspond to keyword arguments names in the functions implementing the linters.

A minimal configuration with one single linter would look as:
```toml
[experiment]
    name = "Configuration with 1 linter"
    target_variable = 2  # column index of target variable in the dataset
[linters]
    # code has to be R; checks for normality of columns
    R_lm_modelling = true
[parameters]
    [parameters.R_lm_modelling]
        # threshold for normality tests; higher values correspond
        # to more strict normal distribution assumptions
        pvalue_threshold = 0.1
```


## Available linters
A short description of the available linters is found below. Their parameters are documented in the configuration files found in the [config](https://github.com/zgornel/DataLinter/tree/master/config) folder.

### Data-only linters
- `datetime_as_string` - checks if dates are wrongly encoded as strings
- ` tokenizable_string` - checks whether the string values of a column can be split into tokens
- ` number_as_string` - checks whether the values of a string column can be converted to numbers
- ` zipcodes_as_values` - checks whether the values correspond to Zip (postal) codes
- ` large_outliers` - checks whether there are large outliers through Tuckey's fences approach
- ` int_as_float` - checks whether floating point encoded values can be converted to integers
- ` enum_detector` - checks whether the column values could correspond to an enumeration i.e. contains small number of distinct values
- ` uncommon_list_lengths` - checks whether the column contains lists of different lengths
- ` duplicate_examples` - checks whether two or more rows are identical
- ` empty_example` - checks for empty examples
- ` uncommon_signs` - checks whether there are very few values with a different sign in a numerical column
- ` long_tailed_distrib` - checks whether the data distribution has a long tail
- ` circular_domain` - checks whether the data pertains to a circular domain i.e. hours, degrees etc.
- ` many_missing_values` - checks whether there are many missing values in the column
- ` negative_values` - checks whether the are negative values in the column
- ` imbalanced_target_variable` - checks whether the values in the column are balanced or not in terms of numbers

### R language specific linters
- ` R_glmmTMB_target_variable` - checks whether the target variable in the `glmmTMB`-specific regression is imbalanced or not
- ` R_glmmTMB_binomial_modelling` - checks whether `link` parameter values are correct for the binomial distribution in the `glmmTMB`-specific regression
- ` R_lm_modelling` - checks whether non-binary numeric columns in `lm`-specific regression are normal or not
- ` R_glm_binomial_modelling` - checks whether non-binary numeric columns in `glm`-specific regression are normal or not
