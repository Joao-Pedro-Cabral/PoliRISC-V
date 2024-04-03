
// FIXME: Move to inside MemoryController directory
interface wishbone_if #(
    parameter integer DATA_SIZE = 32,
    parameter integer ADDR_SIZE = 32
) (
    input clock,
    input reset
);

  logic cyc, stb, we, ack;
  logic [ADDR_SIZE-1:0] addr;
  logic [DATA_SIZE-1:0] dat_i, dat_o;

  modport primary(input clock, reset, ack, dat_o, output addr, cyc, stb, we, dat_i);
  modport secondary(input clock, reset, addr, cyc, stb, we, dat_i, output ack, dat_o);

endinterface : wishbone_if
