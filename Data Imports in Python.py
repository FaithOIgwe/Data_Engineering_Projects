#working with csv

import pandas as pd

loans = pd.read_csv("loan_applications.csv")

print(loans.head())
print("Dataset size:", loans.shape)
print("Column names:", loans.columns)

#importing json files
import pandas as pd

borrowers = pd.read_json("borrower_profiles.json")

print(borrowers.head())
print("Dataset size:", borrowers.shape)
print("Column names:", borrowers.columns)

#viewing data shape
import pandas as pd

loans = pd.read_csv("loan_applications.csv")
borrowers = pd.read_json("borrower_profiles.json")

print("Loans dataset:")
print(loans.head())

print("\nBorrowers dataset:")
print(borrowers.head())

print("\nLoans size:", loans.shape)
print("Borrowers size:", borrowers.shape)

#viewing data types
print("Loan data types:")
print(loans.dtypes)

print("\nBorrower data types:")
print(borrowers.dtypes)
