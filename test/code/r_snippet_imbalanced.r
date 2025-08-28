path <- "./data.csv"
out1 <- loaded_data(path)
out2 <- glmmTMB(col4 ~ col1 + col2 + col3,
                data = out1,
                family = binomial(link = "logit")) # correct
