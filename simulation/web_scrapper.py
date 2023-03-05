from selenium import webdriver
from time import sleep
import re
from selenium.webdriver.support.ui import Select

searchterms = []

with open("riscv_assembly.txt", "r") as assembly:
    for line in assembly:
        if "li" or "mv" or "sext.w" or "jr" in line:
            l = re.sub("^\s+", "", line)
            l = re.sub("\s", ",", l)
            tokens = re.split(",",l)

        if "li" in line:
            searchterms.append("addi "+tokens[1]+","+"x0,"+tokens[2]+"\r\n")
        elif "mv" in line:
            searchterms.append("addi "+tokens[1]+","+tokens[2]+",0\r\n")
        elif "sext.w" in line:
            searchterms.append("addiw "+tokens[1]+","+tokens[2]+",0\r\n")
        elif "jr" in line:
            searchterms.append("jalr x0,"+tokens[1]+",0\r\n")
        else:
            searchterms.append(line)

        print(searchterms[-1])

machine = open("program.mif", "w")

driver_path = "/usr/bin/chromedriver"
brave_path = "/usr/bin/brave-browser"

option = webdriver.ChromeOptions()
option.binary_location = brave_path
# option.add_argument("--incognito") OPTIONAL
# option.add_argument("--headless") OPTIONAL

#Create new Instance of Chrome
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
    machine.write(binary_data[24:32]+"\n")
    machine.write(binary_data[16:24]+"\n")
    machine.write(binary_data[8:16]+"\n")
    machine.write(binary_data[0:8]+"\n")

    browser.find_element("id", "search-input").click();
    browser.find_element("id", "search-input").clear();

browser.quit()
