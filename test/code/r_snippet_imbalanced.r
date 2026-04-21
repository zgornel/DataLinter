library(glmmTMB)
data_path <- "./test/data/imbalanced_data.csv"
out1 <- read.csv(data_path, header=TRUE)
m2 <- glmmTMB(col4 ~ col1 + col2 + col3,
              data = out1,
              family=binomial(link="logit"))
