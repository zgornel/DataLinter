from sklearn.linear_model import LogisticRegression
import pandas as pd

data_path = "./test/data/imbalanced_data.csv"
out1 = pd.read_csv(data_path)
X = out1[["col1", "col2", "col3"]]
y = out1["col4"]

# this code will be tested with JSON data that looks like
# '{"X":"..<contents of X in csv form> .." , 
#   "y":"..<contents of y in csv form> .."
#  }'
model = LogisticRegression()
model.fit(X, y)
