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

#investigating missig values 

loan_missing_values = loans.isna().sum()

borrower_missing_values = borrowers.isna().sum()

print(loan_missing_values)
print(borrower_missing_values)


#find borrowers whose employment_status is missing:
missing_employment = borrowers[
    borrowers["employment_status"].isna()
]

print(missing_employment)


#Find loans that are: Approved and Missing an amount
approved_missing_amount = loans[
    (loans["status"] == "Approved")
    & (loans["amount"].isna())
]

print(approved_missing_amount)
