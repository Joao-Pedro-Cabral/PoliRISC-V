
from defines import *


def write_macros(path: str, new_content: list[str]) -> None:
    # generate lines
    lines = [""]*len(new_content)
    for i, content in enumerate(new_content):
        lines[i] = "`define " + content + "\n"

    # write lines
    with open(path, 'w') as file:
        file.writelines(lines)


def set_macros(testbench: str, path: str) -> None:
    macros_list: str = boards_map.get(testbench, "")
    if macros_list != "":  # testbench needs macros
        write_macros(path, macros_list)
