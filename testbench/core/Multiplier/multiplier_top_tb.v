`timescale 1ns / 1ns

module multiplier_top_tb;

  reg clock = 0;
  reg reset = 0;
  reg valid = 0;
  wire ready;
  reg [15:0] multiplicand = 16'b0;
  reg [15:0] multiplier = 16'b0;
  wire [31:0] product;

  localparam integer ClockPeriod = 20;
  localparam integer NumTests = 100;

  multiplier_top uut_multiplier (
      .clock(clock),
      .reset(reset),
      .valid(valid),
      .ready(ready),
      .multiplicand(multiplicand),
      .multiplier(multiplier),
      .product(product)
  );

  always #(ClockPeriod / 2) clock = ~clock;

  function integer rand_int(integer min_val, integer max_val);
    real r;
    integer seed1 = 123456789;
    integer seed2 = 987654321;

    begin
      $urandom(seed1, seed2, r);
      rand_int = $floor(r * (max_val - min_val + 1) + min_val);
    end
  endfunction

  initial begin
    // Reset the system
    reset = 1;
    #ClockPeriod;
    reset = 0;

    // Run tests
    repeat (NumTests) begin
      // Generate random inputs using rand_int
      multiplicand = rand_int(0, 65535);
      multiplier = rand_int(0, 65535);

      // Assert valid
      valid = 1;
      #1;
      valid = 0;

      // Wait for the result
      @(posedge ready);
      #1;

      // Assert correctness of the result
      if (product !== multiplicand * multiplier) begin
        $fatal("Multiplication result is incorrect");
      end

      #ClockPeriod;
    end

    // Finish the simulation
    $display("Calling 'stop'");
    $stop;
  end

endmodule
