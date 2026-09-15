import pandas as pd

loans = pd.read_csv("loan_applications.csv")

print(loans.head())
print("Dataset size:", loans.shape)
print("Column names:", loans.columns)

