module display (
    input [7:0] ascii,
    output reg [6:0] hexa
);

  always @(*) begin
    case (ascii)
      8'h30:   hexa = 7'b1000000;  // 0
      8'h31:   hexa = 7'b1111001;  // 1
      8'h32:   hexa = 7'b0100100;  // 2
      8'h33:   hexa = 7'b0110000;  // 3
      8'h34:   hexa = 7'b0011001;  // 4
      8'h35:   hexa = 7'b0010010;  // 5
      8'h36:   hexa = 7'b0000010;  // 6
      8'h37:   hexa = 7'b1111000;  // 7
      8'h38:   hexa = 7'b0000000;  // 8
      8'h39:   hexa = 7'b0010000;  // 9
      default: hexa = 7'b1111111;  // Blank
    endcase
  end

endmodule
