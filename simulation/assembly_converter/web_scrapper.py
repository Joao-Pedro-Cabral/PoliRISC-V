from selenium import webdriver
from time import sleep
import re
from selenium.webdriver.support.ui import Select

# Tradução de pseudoinstruções


def li(tokens):
    if (int(tokens[2]) < 4096):
        return "addi "+tokens[1]+","+"x0,"+tokens[2]+"\n"
    else:
        return "lui "+tokens[1]+","+tokens[2]+"\n"


def mv(tokens):
    return "addi "+tokens[1]+","+tokens[2]+",0\n"


def sextw(tokens):
    return "addiw "+tokens[1]+","+tokens[2]+",0\n"


def jr(tokens):
    return "jalr x0,0("+tokens[1]+")\n"


def j(tokens):
    return "jal x0,"+tokens[1]+"\n"
###############################


searchterms = []
pseudoinstructions = {
    "li": li,
    "mv": mv,
    "sext.w": sextw,
    "jr": jr,
    "j": j
}

with open("assembly/" + input("digite o nome do arquivo: "), "r") as assembly:
    for line in assembly:
        if len(line.strip()) == 0:
            continue

        if line[len(line) - len(line.lstrip())] in [';', '#', '/']:
            continue

        # apaga espaços no começo da linha
        l = re.sub("^\s+", "", line)

        # verifica se há pseudoinstrução
        temp = re.split(" ", line)
        has_pseudoinstruction = False
        for pseudoinst in pseudoinstructions.keys():
            if pseudoinst in temp:
                has_pseudoinstruction = True
                pseudo_dict_entry = pseudoinst
                l = re.sub("\s", ",", l)
                tokens = re.split(",", l)
                break

        if has_pseudoinstruction:
            searchterms.append(pseudoinstructions.get(
                pseudo_dict_entry, lambda: "Invalid")(tokens))
        else:
            searchterms.append(l)

machine = open("program.mif", "w")

brave_path = "/usr/bin/brave-browser"

option = webdriver.ChromeOptions()
option.add_argument("--port=11000")
option.add_argument("--headless=new")
option.binary_location = brave_path
browser = webdriver.Chrome(options=option)

browser.get("https://luplab.gitlab.io/rvcodecjs/")

browser.find_element("id", "parameter-button").click()
isa = browser.find_element("id", "isa")
dropdown = Select(isa)
dropdown.select_by_value(input("Selecione arquitetura (RV32I ou RV64I): "))
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

    browser.find_element("id", "search-input").click()
    browser.find_element("id", "search-input").clear()

browser.close()
browser.quit()
