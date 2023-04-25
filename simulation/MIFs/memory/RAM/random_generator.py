from random import randint

# Define the file name and the number of words to generate
file_name = "random_numbers.mif"
num_words = 64*2**20

# Define the number of bits per word and the maximum value for each bit
num_bits = 8
max_value = 2 ** num_bits - 1

# Open the file for writing
with open(file_name, "w") as f:
    # Write the header information
    # Generate random binary numbers and write them to the file
    for i in range(num_words):
        value = randint(0, max_value)
        binary = "{:08b}".format(value)
        f.write("{}\n".format(binary))

# Print a message to indicate that the file was generated
print("File {} generated.".format(file_name))

