from selenium import webdriver
from time import sleep
import re
from selenium.webdriver.support.ui import Select

# Tradução de pseudoinstruções
def li(tokens):
    if(int(tokens[2]) < 4096):
        return "addi "+tokens[1]+","+"x0,"+tokens[2]+"\n"
    else:
        return "lui "+tokens[1]+","+tokens[2]+"\n"

def mv(tokens):
    return "addi "+tokens[1]+","+tokens[2]+",0\n"

def sextw(tokens):
    return "addiw "+tokens[1]+","+tokens[2]+",0\n"

def jr(tokens):
    return "jalr x0,"+tokens[1]+",0\n"
###############################

searchterms = []
pseudoinstructions= {
        "li":li,
        "mv":mv,
        "sext.w":sextw,
        "jr":jr
        }

with open("riscv_assembly.txt", "r") as assembly:
    for line in assembly:

        # apaga espaços no começo da linha
        l = re.sub("^\s+", "", line)

        # verifica se há pseudoinstrução
        temp = re.split(" ", line)
        has_pseudoinstruction = False
        for pseudoinst in pseudoinstructions.keys():
            if pseudoinst in temp:
                has_pseudoinstruction = True
                pseudo_dict_entry = pseudoinst;
                l = re.sub("\s", ",", l)
                tokens = re.split(",",l)
                break

        if has_pseudoinstruction:
            searchterms.append(pseudoinstructions.get(pseudo_dict_entry, lambda: "Invalid")(tokens))
        else:
            searchterms.append(l)

machine = open("program.mif", "w")

driver_path = "/usr/bin/chromedriver"
brave_path = "/usr/bin/brave-browser"

option = webdriver.ChromeOptions()
option.binary_location = brave_path
browser = webdriver.Chrome(executable_path=driver_path, chrome_options=option)

browser.get("https://luplab.gitlab.io/rvcodecjs/")

browser.find_element("id", "parameter-button").click()
isa = browser.find_element("id", "isa")
dropdown = Select(isa)
dropdown.select_by_value("RV64I")
browser.find_element("id", "close").click()

for searchterm in searchterms:
    sbox = browser.find_element("id", "search-input")
    sbox.send_keys(searchterm)

    binary_data = browser.find_element("id", "binary-data").text
    binary_data = re.sub("\s+", "", binary_data)
    machine.write(binary_data[24:32]+" // "+searchterm)
    machine.write(binary_data[16:24]+"\n")
    machine.write(binary_data[8:16]+"\n")
    machine.write(binary_data[0:8]+"\n")

    browser.find_element("id", "search-input").click();
    browser.find_element("id", "search-input").clear();

browser.close()
browser.quit()
