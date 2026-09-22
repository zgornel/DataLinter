from sklearn.linear_model import LogisticRegression
import pandas as pd

data_path = "./test/data/imbalanced_data.csv"
out1 = pd.read_csv(data_path)
X = out1[["col1", "col2", "col3"]]
col4 = out1["col4"]

model = LogisticRegression()
model.fit(X, col4)
