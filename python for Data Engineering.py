# You have a list of loan amounts:
loan_amounts = [5000, 10000, 15000, 20000]

# Write a for loop that prints each loan amount.
for items in loan_amounts:
    print(loan_amounts)

# Now try changing the loop so it prints each loan amount multiplied by 2
loan_amounts = [5000, 10000, 15000, 20000]

for item in loan_amounts:
    print(item * 2)

#Print only the loan amounts greater than 10,000.
for item in loan_amounts:
    if item > 10000:
        print(item)
