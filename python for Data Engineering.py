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


# Print whether each loan is "Small" or "Large": 10,000 or less → "Small", Greater than 10,000 → "Large"
for item in loan_amounts:
    if item > 10000:
        print(item, "Large")
    else:
        print(item, "Small")

#Practice 4 (Count how many loans are greater than 10,000.)
#loan_amounts = [5000, 10000, 15000, 20000]
large_loan_count = 0

for item in loan_amounts:
    if item > 10000:
        large_loan_count += 1

print(large_loan_count)

#Calculate the total of all the loan amounts without using sum():
loan_amounts = [5000, 10000, 15000, 20000]

total_amount = 0

for item in loan_amounts:
    total_amount += item

print(total_amount)

#Calculate the total of only the loan amounts greater than 10,000.
loan_amounts = [5000, 10000, 15000, 20000]

large_loan_total = 0

for item in loan_amounts:
    if item > 10000:
        large_loan_total += item

print(large_loan_total)




