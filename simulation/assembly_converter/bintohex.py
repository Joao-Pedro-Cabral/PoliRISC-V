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
                if i == 3:
                    broken_binary_lines[3] = binary_line
                    binary_lines.append(mount_binary_line(broken_binary_lines))
                    i = 0
                else:
                    broken_binary_lines[i] = binary_line
                    i = i + 1
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return None

    return binary_lines


def main():
    machine = open("program.hex", "w")

    file_path: str = input("Digite o nome do arquivo: ").strip()

    binary_lines: list[str] = read_binary_from_file(file_path)

    for line in binary_lines:

        # Convert the combined binary to hexadecimal
        hex_result = binary_to_hex(line)

        machine.write("0x" + hex_result + "\n")


if __name__ == "__main__":
    main()
