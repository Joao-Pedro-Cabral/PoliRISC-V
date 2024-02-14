def binary_to_hex(binary_str: str) -> str:
    decimal_value = int(binary_str, 2)
    hex_value = hex(decimal_value)[2:].upper().zfill(8)
    return hex_value


def mount_binary_line(broken_lines: list[str]) -> str:
    return ''.join(broken_lines[::-1])


def read_binary_from_file(file_path: str) -> list[str]:
    binary_lines = []
    broken_binary_lines = ["0", "0", "0", "0"]
    i = 0
    try:
        with open(file_path, 'r') as file:
            for line in file:
                binary_line = line.strip()

                # Ensure the line has exactly 8 binary digits
                if len(binary_line) != 8 or not all(bit in '01' for bit in binary_line):
                    print(f"Invalid input in the file. Line: {binary_line}")
                    return None
                broken_binary_lines[i] = binary_line
                if i == 3:
                    binary_lines.append(mount_binary_line(broken_binary_lines))
                i = (i + 1) % 4
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return None

    return binary_lines


def bintohex(file_path: str) -> list[str]:
    binary_lines: list[str] = read_binary_from_file(file_path)
    hex_lines: list[str] = []

    for line in binary_lines:

        # Convert the combined binary to hexadecimal
        hex_lines.append(binary_to_hex(line) + "\n")

    return hex_lines
