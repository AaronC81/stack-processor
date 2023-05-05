module seven_seg (
    input clk, input [4:0] digit,
    output A, output B, output C, output D, output E, output F, output G
);
    //   a
    // f   b
    //   g
    // e   c
    //   d

    reg [6:0] state;
    assign A = state[6];
    assign B = state[5];
    assign C = state[4];
    assign D = state[3];
    assign E = state[2];
    assign F = state[1];
    assign G = state[0];

    always @(posedge clk) begin
        case (digit)
            5'd0: state <= 7'b1111110;
            5'd1: state <= 7'b0110000;
            5'd2: state <= 7'b1101101;
            5'd3: state <= 7'b1111001;
            5'd4: state <= 7'b0110011;
            5'd5: state <= 7'b1011011;
            5'd6: state <= 7'b1011111;
            5'd7: state <= 7'b1110000;
            5'd8: state <= 7'b1111111;
            5'd9: state <= 7'b1111011;

            default: state <= 7'b0000001;
        endcase
    end
endmodule

module top (
    input CLK,
    output LED,
    output USBPU,

    output PIN_15, // A
    output PIN_14, // B
    output PIN_13, // C
    output PIN_12, // D
    output PIN_11, // E
    output PIN_16, // F
    output PIN_17, // G
);
    assign USBPU = 0;

    seven_seg seven_seg_inst(
        .clk(CLK),
        .digit(instruction_index),
        .A(PIN_15),
        .B(PIN_14),
        .C(PIN_13),
        .D(PIN_12),
        .E(PIN_11),
        .F(PIN_16),
        .G(PIN_17),
    );

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
