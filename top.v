module top (
    input CLK,
    output LED,
    output USBPU
);
    assign USBPU = 0;

    wire [7:0] instructions [0:3];
    assign instructions[0] = 8'b00000000; // nop
    assign instructions[1] = 8'b00000010; // off
    assign instructions[2] = 8'b00000001; // nop
    assign instructions[3] = 8'b00000011; // on

    reg [1:0] instruction_index = 0;

    // 2^22 * (1 / 16MHz) =~ 0.25s per clock
    reg [22:0] instruction_clock_counter = 0;
    wire instruction_clock = instruction_clock_counter[22];
    always @(posedge CLK) begin
        instruction_clock_counter <= instruction_clock_counter + 1;
    end

    reg led = 0;
    assign LED = led;
    always @(posedge instruction_clock) begin
        case (instructions[instruction_index])
            8'b00000000:;
            8'b00000010: led <= 0;
            8'b00000011: led <= 1;
            default:;
        endcase
    end
    always @(negedge instruction_clock) begin
        instruction_index <= instruction_index + 1;
    end
endmodule
