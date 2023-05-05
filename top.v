module top (
    input CLK,
    output LED,
    output USBPU
);
    assign USBPU = 0;

    //                              wait      off      wait      on    
    wire [31:0] instructions = 32'b00000001_00000010_00000001_00000011;
    reg [1:0] instruction_index = 0;

    // 2^24 * (1 / 16MHz) =~ 1.04s per clock
    reg [24:0] instruction_clock_counter;
    wire instruction_clock = instruction_clock_counter[24];
    always @(posedge CLK) begin
        instruction_clock_counter <= instruction_clock_counter + 1;
    end

    reg led = 0;
    assign LED = led;
    always @(posedge instruction_clock) begin
        led <= ~led;
    end
endmodule
