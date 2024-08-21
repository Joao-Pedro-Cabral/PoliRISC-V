
import subprocess
import sys
from manifest_utils import *
from defines import *


def find_files(root_directory: str, extension: str):
    # Use the find command to locate files
    command = ['find', root_directory, '-type', 'f', '-name', f'*.{extension}']
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode == 0:
        files = result.stdout.strip().split('\n')
        # Obtain only the file name
        return [file.split('/')[-1].split('.')[0] for file in files]
    else:
        print(f"Error executing find command: {result.stderr}")
        return []


# MAIN
sys.stdout = open("../log.txt", "w")
# Get all testbenches files
sim_top_array = find_files("../../testbench", "sv")
print("############## tops: " + str(sim_top_array))
# Get mifs files for core simulation
mif_array = find_files("../MIFs/memory/ROM/core", "mif")
print("############## mifs: " + str(mif_array))

write_lines(["gui_mode"], ["gui_mode = False"])  # Set TCL Mode
write_lines(["use_mif"], ["use_mif = True"])  # Set Mifs
# No support for RV64I
write_lines(["lista_de_extensoes"], ["lista_de_extensoes = []"])
# Nexys4 with Litex
write_lines(["board_list"], ["board_list = [\"LITEX\", \"NEXYS4\"]"])

for testbench in sim_top_array:
    if not testbench.endswith("_tb"):
        continue
    print(f'---------{testbench}---------')
    write_lines(["sim_top"], [f"sim_top = \"{testbench}\""])
    if testbench in excluded_tops:
        print("---------PASS---------")
    elif tops_with_mifs.count(testbench) != 0:
        for i, mif in enumerate(mif_array):
            write_lines(["mif_name"], [f"mif_name = \"{mif}.mif\""])
            run_simulation()
    else:
        run_simulation()
