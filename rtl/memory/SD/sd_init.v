module sd_init #(
    parameter reg CPOL = 1'b0
) (
    // sinais de sistema
    input clock,
    input reset,

    // interface com o cartão SD
    input miso,
    output reg cs,
    output reg sck,
    output reg mosi,

    // sinais de status
    input  init_en,
    output init_busy
);

  reg  cmd_index;
  reg  argument;
  reg  cmd_valid;
  wire cmd_sender_mosi;

  sd_cmd_sender cmd_sender (
      .clock(clock),
      .reset(reset),

      .cmd_index(cmd_index),
      .argument (argument),
      .cmd_valid(cmd_valid),

      // interface com o cartão SD
      .mosi(cmd_sender_mosi),

      .sending_cmd(sending_cmd)
  );


  reg new_cs;
  reg new_sck;

  localparam reg [7:0]
    Idle = 8'h00,
    Cmd0 = 8'h03,
    Cmd8 = 8'h04,
    Cmd8R1 = 8'h05,
    Cmd8B2 = 8'h06,
    Cmd8B3 = 8'h07,
    Cmd8B4 = 8'h08,
    Cmd8GotB4 = 8'h09,
    Cmd55 = 8'h0A,
    Acmd41 = 8'h0B,
    PollCmd = 8'h0C,
    Cmd58 = 8'h0D,
    Cmd58R1 = 8'h0E,
    Cmd58B2 = 8'h0F,
    Cmd58B3 = 8'h10,
    Cmd58B4 = 8'h11,
    WaitCmd = 8'h12;

  reg [7:0] new_state, state, new_state_return;

  always @(posedge clk) begin
    if (reset) begin
      cs    <= 1'b1;
      sck   <= CPOL;
      mosi  <= 1'b1;
      state <= Idle;
    end else begin
      cs    <= new_cs;
      sck   <= new_sck;
      state <= new_state;
    end
  end

  task reset_signals;
    begin
      new_cs = 1'b1;
      new_sck = CPOL;
      new_state_return = Idle;
      cmd_index = 6'b000000;
      argument = 32'b0;
      cmd_valid = 1'b0;
    end
  endtask

  always @(*) begin
    reset_signals;

    case (state)
      Idle: begin
        if (init_en) new_state = Cmd0;
        else new_state = Idle;
      end

      WaitCmd: begin
        if (!sending_cmd) new_state = new_state_return;
        else begin
          new_cs = 1'b0;
          new_state = WaitCmd;
        end
      end

      Cmd0: begin
        new_cs = 1'b0;
        cmd_index = 6'b000000;
        argument = 32'b0;
        cmd_valid = 1'b1;
        new_state = WaitCmd;
        new_state_return = Cmd8;
      end

      Cmd8: begin
      end

      Cmd8R1: begin
      end

      Cmd8B2: begin
      end

      Cmd8B3: begin
      end

      Cmd8B4: begin
      end

      Cmd8GotB4: begin
      end

      Cmd55: begin
      end

      Acmd41: begin
      end

      PollCmd: begin
      end

      Cmd58: begin
      end

      Cmd58R1: begin
      end

      Cmd58B2: begin
      end

      Cmd58B3: begin
      end

      Cmd58B4: begin
      end

      default: begin
      end
    endcase
  end

  assign init_busy = state != Idle;
  assign mosi = state == WaitCmd ? cmd_sender_mosi : 1'b1;

endmodule
