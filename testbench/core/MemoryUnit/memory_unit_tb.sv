module memory_unit_tb;
  import macros_pkg::*;

  localparam integer Seed = 42069;
  localparam integer ClockPeriod = 10;
  localparam integer Width = 32;

  logic clock;
  logic reset;
  logic rd_data_mem;
  logic wr_data_mem;
  logic inst_mem_ack;
  logic [Width-1:0] inst_mem_rd_dat;
  logic data_mem_ack;
  logic [Width-1:0] data_mem_rd_dat;
  logic inst_mem_en;
  logic [Width-1:0] inst_mem_dat;
  logic data_mem_en;
  logic data_mem_we;
  logic [Width-1:0] data_mem_dat;
  logic busy;

  // internal signals
  logic [2:0] wait_time;

  memory_unit #(.InstSize(Width), .DataSize(Width)) DUT (.*);

  initial begin
    $display("SOT!");
    init_vars;
    reset_module_test;
    only_inst_mem_read_test;
    inst_mem_read_then_data_mem_op(1'b0);
    inst_mem_read_then_data_mem_op(1'b1);
    data_mem_op_then_inst_mem_read(1'b0);
    data_mem_op_then_inst_mem_read(1'b1);
    simultaneous_mem_ops(1'b0);
    simultaneous_mem_ops(1'b1);
    $display("EOT!");
    $stop;
  end

  task automatic init_vars;
    clock = '0;
    reset = '0;
    rd_data_mem = '0;
    wr_data_mem = '0;
    inst_mem_ack = '0;
    inst_mem_rd_dat = '0;
    data_mem_ack = '0;
    data_mem_rd_dat = '0;

    //internal signals
    wait_time = '0;
    void'($urandom(Seed));
  endtask

  task automatic reset_module_test;
    reset = 1'b1;
    @(posedge clock);
    @(negedge clock);
    RESET_MODULE_TEST :
    assert (busy & inst_mem_en) $display("reset_module_test OK");
    else $stop;

    @(posedge clock);
    reset = 1'b0;
  endtask

  task automatic only_inst_mem_read_test;
    rd_data_mem = 1'b0;
    wr_data_mem = 1'b0;
    inst_mem_ack = 1'b0;
    inst_mem_rd_dat = $urandom;
    @(negedge clock);

    WAIT_INST_MEM_TRANSITION_TEST :
    assert (busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;
    INST_MEM_DAT_NE_TEST :
    assert (inst_mem_dat !== inst_mem_rd_dat)
    else $stop;

    wait_time = $urandom;
    #(wait_time);

    WAIT_INST_MEM_TEST :
    assert (busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;

    @(posedge clock);
    inst_mem_ack = 1'b1;
    @(negedge clock);

    IDLE_TRANSITION_TEST :
    assert (~busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;
    INST_MEM_DAT_EQ_TEST :
    assert (inst_mem_dat === inst_mem_rd_dat)
    else $stop;

    @(posedge clock);
    inst_mem_ack = 1'b0;
    #(ClockPeriod / 4);

    IDLE_TEST :
    assert (busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;
  endtask

  task automatic inst_mem_read_then_data_mem_op(input bit rd_or_wr);
    wait_any_mem_test(rd_or_wr);

    @(posedge clock);
    inst_mem_ack = 1'b1;
    @(negedge clock);

    WAIT_DATA_MEM_TRANSITION_TEST :
    assert (busy & inst_mem_en & data_mem_en & (data_mem_we == rd_or_wr))
    else $stop;

    @(posedge clock);
    inst_mem_ack = 1'b0;
    @(negedge clock);
    INST_MEM_DAT_EQ_TEST :
    assert (inst_mem_dat === inst_mem_rd_dat)
    else $stop;
    @(negedge clock);

    WAIT_DATA_MEM :
    assert (busy & ~inst_mem_en & data_mem_en & (data_mem_we == rd_or_wr))
    else $stop;

    @(posedge clock);
    data_mem_ack = 1'b1;
    @(negedge clock);

    IDLE_TRANSITION_TEST :
    assert (~busy & ~inst_mem_en & data_mem_en & (data_mem_we == rd_or_wr))
    else $stop;

    @(posedge clock);
    data_mem_ack = 1'b0;
    rd_data_mem  = 1'b0;
    wr_data_mem  = 1'b0;
    if (~rd_or_wr) begin
      DATA_MEM_DAT_EQ_TEST :
      assert (data_mem_dat === data_mem_rd_dat)
      else $stop;
    end
    #(ClockPeriod / 4);

    IDLE_TEST :
    assert (busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;
  endtask

  task automatic data_mem_op_then_inst_mem_read(input bit rd_or_wr);
    wait_any_mem_test(rd_or_wr);

    @(posedge clock);
    data_mem_ack = 1'b1;
    @(negedge clock);

    WAIT_INST_MEM_TRANSITION_TEST :
    assert (busy & inst_mem_en & data_mem_en & (data_mem_we == rd_or_wr))
    else $stop;

    @(posedge clock);
    data_mem_ack = 1'b0;
    rd_data_mem  = 1'b0;
    wr_data_mem  = 1'b0;
    if (~rd_or_wr) begin
      DATA_MEM_DAT_EQ_TEST :
      assert (data_mem_dat === data_mem_rd_dat)
      else $stop;
    end
    @(negedge clock);

    WAIT_INST_MEM :
    assert (busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;

    @(posedge clock);
    inst_mem_ack = 1'b1;
    @(negedge clock);

    IDLE_TRANSITION_TEST :
    assert (~busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;

    @(posedge clock);
    inst_mem_ack = 1'b0;
    INST_MEM_DAT_EQ_TEST :
    assert (inst_mem_dat === inst_mem_rd_dat)
    else $stop;
    #(ClockPeriod / 4);

    IDLE_TEST :
    assert (busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;
  endtask

  task automatic simultaneous_mem_ops(input bit rd_or_wr);
    wait_any_mem_test(rd_or_wr);

    @(posedge clock);
    inst_mem_ack = 1'b1;
    data_mem_ack = 1'b1;
    @(negedge clock);

    IDLE_TRANSITION_TEST :
    assert (~busy & inst_mem_en & data_mem_en & (data_mem_we == rd_or_wr))
    else $stop;

    @(posedge clock);
    inst_mem_ack = 1'b0;
    data_mem_ack = 1'b0;
    rd_data_mem  = 1'b0;
    wr_data_mem  = 1'b0;
    INST_MEM_DAT_EQ_TEST :
    assert (inst_mem_dat === inst_mem_rd_dat)
    else $stop;
    if (~rd_or_wr) begin
      DATA_MEM_DAT_EQ_TEST :
      assert (data_mem_dat === data_mem_rd_dat)
      else $stop;
    end
    #(ClockPeriod / 4);

    IDLE_TEST :
    assert (busy & inst_mem_en & ~data_mem_en & ~data_mem_we)
    else $stop;
  endtask

  task automatic wait_any_mem_test(input bit rd_or_wr);
    rd_data_mem = ~rd_or_wr;
    wr_data_mem = rd_or_wr;
    inst_mem_rd_dat = $urandom;
    data_mem_rd_dat = $urandom;
    @(negedge clock);

    WAIT_ANY_MEM_TRANSITION_TEST :
    assert (busy & inst_mem_en & data_mem_en & (data_mem_we == rd_or_wr))
    else $stop;
    INST_MEM_DAT_NE_TEST :
    assert (inst_mem_dat !== inst_mem_rd_dat)
    else $stop;
    DATA_MEM_DAT_NE_TEST :
    assert (data_mem_dat !== data_mem_rd_dat)
    else $stop;

    @(posedge clock);
    wait_time = $urandom;
    #(wait_time);

    WAIT_ANY_MEM_TEST :
    assert (busy & inst_mem_en & data_mem_en & (data_mem_we == rd_or_wr))
    else $stop;
  endtask

  always #(ClockPeriod / 2) clock = ~clock;

endmodule
