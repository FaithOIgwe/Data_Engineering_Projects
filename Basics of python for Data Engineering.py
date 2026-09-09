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


#The loop so that it prints the numbers from 1 to 5:
number = 1

while number <= 5:
    print(number)
    number += 1

#Print only the even numbers from 2 to 10.
number = 2

while number <= 10:
    print(number)
    number += 2

#Calculate the total of the numbers from 1 to 5.
number = 1
total = 0

while number <= 5:
    total += number
    number += 1

print(total)

#Print only the numbers greater than 3.
number = 1

while number <= 10:
    if number == 4:
        __________

    print(number)
    number += 1

# loop so it stops when number becomes 4
number = 1

while number <= 10:
    if number == 4:
        __________

    print(number)
    number += 1

#Complete this loop so it prints every number except 3:
number = 0

while number < 5:
    number += 1

    if number == 3:
        continue

    print(number)

#Complete this code without using min():
smallest_approved_amount = None

for loan in loans:
    if loan["status"] == "Approved":
        if smallest_approved_amount is None or loan["amount"] < smallest_approved_amount:
            smallest_approved_amount = loan["amount"]

print("Smallest Approved Amount:", smallest_approved_amount)

#Categorize approved loans
#Count approved loans as either "Small" or "Large":
#Small: amount is 10,000 or less
#Large: amount is greater than 10,000
small_approved_count = 0
large_approved_count = 0

for loan in loans:
    if loan["status"] == "Approved":
        if loan["amount"] <= 10000:
            small_approved_count += 1
        else:
            large_approved_count += 1

print("Small approved loans:", small_approved_count)
print("Large approved loans:", large_approved_count)


# Build a list of approved loan IDs
approved_loan_ids = []

for loan in loans:
    if loan["status"] == "Approved":
        approved_loan_ids.append(loan["id"])

print("Approved loan IDs:", approved_loan_ids)


#Create an ETL-style output

#Transform the approved loans into new records:

approved_records = []

for loan in loans:
    if loan["status"] == "Approved":
        transformed_loan = {
            "loan_id": loan["id"],
            "amount": loan["amount"],
            "amount_category": (
                "Small" if loan["amount"] <= 10000 else "Large"
            )
        }

        approved_records.append(transformed_loan)

for record in approved_records:
    print(record)
