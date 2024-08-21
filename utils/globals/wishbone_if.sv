
interface wishbone_if #(
    parameter integer DATA_SIZE = 32,
    parameter integer BYTE_SIZE = 8,
    parameter integer ADDR_SIZE = 32
) (
    input clock,
    input reset
);

  logic cyc, stb, we, ack, tgd;
  logic [ADDR_SIZE-1:0] addr;
  logic [DATA_SIZE/BYTE_SIZE-1:0] sel;
  logic [DATA_SIZE-1:0] dat_i_p, dat_o_p, dat_i_s, dat_o_s;

  modport primary(input clock, reset, ack, dat_i_p, output addr, cyc, stb, we, sel, tgd, dat_o_p,
                  import rd_en, wr_en);
  modport secondary(input clock, reset, addr, cyc, stb, we, tgd, sel, dat_i_s, output ack, dat_o_s,
                  import rd_en, wr_en);

  assign dat_i_p = dat_o_s;
  assign dat_i_s = dat_o_p;

  function automatic logic rd_en();
    return cyc & stb & ~we;
  endfunction

  function automatic logic wr_en();
    return cyc & stb & we;
  endfunction

  function automatic logic op_en();
    return cyc & stb;
  endfunction

endinterface : wishbone_if
