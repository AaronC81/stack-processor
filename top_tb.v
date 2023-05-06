// From: https://myz80.wordpress.com/2020/11/01/simulation-of-tinyfpga-design-and-testbenches/

`timescale 1 ns/10 ps
 
module top_tb; 
    wire LED;
    reg clk;

    wire [31:0] stack_top;
    wire [31:0] stack_count;

    main top_inst (.LED (LED) , .CLK (clk), .STACK_TOP_ITEM(stack_top), .STACK_ITEM_COUNT(stack_count));
    defparam top_inst.INSTRUCTION_CLOCK_BIT = 2;
    
    always
    begin
        clk = 1'b1;
        # 20;
    
        clk = 1'b0;
        # 20;
    end
    
    integer test_out;
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        # 10000
        
        test_out = $fopen("top_tb_data.rb");
        $fdisplay(test_out, "top = %d", stack_top);
        $fdisplay(test_out, "count = %d", stack_count);

        $finish;
    end
endmodule
