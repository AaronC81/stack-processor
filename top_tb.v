// From: https://myz80.wordpress.com/2020/11/01/simulation-of-tinyfpga-design-and-testbenches/

`timescale 1 ns/10 ps
 
module top_tb; 
  wire LED;
  reg clk;
 
  top top_inst ( .LED (LED) , .CLK (clk) );
  defparam top_inst.INSTRUCTION_CLOCK_BIT = 2;
 
  always
  begin
      clk = 1'b1;
      # 20;
  
      clk = 1'b0;
      # 20;
  end
 
  initial begin
      $dumpfile("top_tb.vcd");
      $dumpvars(0, top_tb);
      # 2000 $finish;
  end
endmodule
