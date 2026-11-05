from sklearn.linear_model import LogisticRegression
import pandas as pd

data_path = "./test/data/imbalanced_data.csv"
out1 = pd.read_csv(data_path)
X = out1[["col1", "col2", "col3"]]
col4= out1["col4"]

model = LogisticRegression()

# this is a trick to make the test work:
# the parser takes the symbol 'col4' as target column. In the test,
# the data sent for parsing is not however 'X' but the contents of
# 'out1' which contains a column 'col4'
model.fit(X, col4)
