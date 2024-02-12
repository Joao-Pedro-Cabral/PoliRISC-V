from selenium import webdriver
from time import sleep
import re
from selenium.webdriver.support.ui import Select
from bintohex import bintohex

searchterms = []

mif_path: str = input("Digite o nome do arquivo: ").strip()
searchterms = bintohex(mif_path)

machine = open("program.s", "w")

brave_path = "/usr/bin/brave-browser"

option = webdriver.ChromeOptions()
option.add_argument("--port=11000")
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

    asm_data = browser.find_element("id", "asm-data").text
    machine.write(asm_data + " // " + searchterm + "\n")

    browser.find_element("id", "search-input").click()
    browser.find_element("id", "search-input").clear()

browser.close()
browser.quit()
