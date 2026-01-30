path <- "~/projects/DataLinter/test/data/imbalanced_data.csv"
out1 <- read.csv(path, header=TRUE)
m2 <- lm(col4 ~ col1 + col2 + col3, data = out1)
print(m2)
