import subprocess
from defines import macros_map


def write_lines(search_string: list[str], new_content: list[str]) -> None:
    # Read the content of the file
    with open("../Manifest.py", 'r') as file:
        lines = file.readlines()

    line_number = [0]*len(search_string)
    for j, string in enumerate(search_string):
        for i, line in enumerate(lines):
            if line.startswith(string):
                line_number[j] = i + 1  # Line numbers start from 1
                break

    for j, content in enumerate(new_content):
        if line_number[j] != 0:
            # Overwrite the specified line with new content
            lines[line_number[j] - 1] = content + '\n'

            # Write the modified content back to the file
            with open("../Manifest.py", 'w') as file:
                file.writelines(lines)
        else:
            print(f"String '{search_string[j]}' not found in the file.")


def set_macros(testbench: str) -> None:
    macros_list: str = macros_map.get(testbench, "")
    if macros_list != "":  # testbench needs macros
        write_lines(["lista_de_macros"],
                    [f"lista_de_macros = {str(macros_list)}"])


def run_simulation() -> None:
    result = subprocess.run(['hdlmake'],
                            capture_output=True, text=True, cwd="..")
    print(result.stdout + result.stderr)
    result = subprocess.run(['make'],
                            capture_output=True, text=True, cwd="..")
    print(result.stdout + result.stderr)
