from riscv_assembler.convert import AssemblyConverter

cnv = AssemblyConverter(output_type="t", nibble=False, hexMode=False)
cnv.convert("riscv_assembly.s")


