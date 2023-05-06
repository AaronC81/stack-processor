/*
Single-digit seven segment display driver.
Supports digits 0-9 plus an extra "invalid" display (shown as "-").

Segment mapping:
.-------.
|   a   |
| f   b |
|   g   |
| e   c |
|   d   |
'-------'

On `clk`:
- If `valid` set, updates to show `digit`.
- If `valid` not set, updates to show "-".
*/ 
module seven_seg (
    input clk, input [4:0] digit, input valid,
    output A, output B, output C, output D, output E, output F, output G
);

    reg [6:0] state;
    assign A = state[6];
    assign B = state[5];
    assign C = state[4];
    assign D = state[3];
    assign E = state[2];
    assign F = state[1];
    assign G = state[0];

    always @(posedge clk) begin
        if (valid) begin
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
        else state <= 7'b0000001;
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
    output PIN_17  // G
);
    assign USBPU = 0;

    seven_seg seven_seg_inst(
        .clk(CLK),
        .digit(stack_top_item),
        .valid(stack_not_empty),
        .A(PIN_15),
        .B(PIN_14),
        .C(PIN_13),
        .D(PIN_12),
        .E(PIN_11),
        .F(PIN_16),
        .G(PIN_17)
    );

    reg [31:0] stack [0:255];
    reg [7:0] stack_pointer = 255;

    wire [31:0] stack_top_item;
    assign stack_top_item = stack[stack_pointer + 1];

    wire stack_is_empty;
    assign stack_is_empty = stack_pointer == 255;
    wire stack_not_empty;
    assign stack_not_empty = ~stack_is_empty;

    integer i;
    initial begin
        for (i = 0; i <= 255; i = i + 1)
            stack[i] = 0;
    end

    wire [7:0] instructions [0:7];
    assign instructions[0] = 8'h10; // push
    assign instructions[1] = 8'h00; //   xx000000
    assign instructions[2] = 8'h00; //   00xx0000
    assign instructions[3] = 8'h00; //   0000xx00
    assign instructions[4] = 8'h06; //   000000xx
    assign instructions[5] = 8'h20; // inc
    assign instructions[6] = 8'h20; // inc
    assign instructions[7] = 8'hFF; // halt

    reg [31:0] instruction_index = 0;
    reg instruction_had_32bit_immediate = 0;

    // 2^22 * (1 / 16MHz) =~ 0.25s per clock
    reg [22:0] instruction_clock_counter = 0;
    wire instruction_clock = instruction_clock_counter[22];
    reg halted = 0;
    always @(posedge CLK) begin
        if (~halted)
            instruction_clock_counter <= instruction_clock_counter + 1;
    end

    reg led = 0;
    assign LED = led;

    // We can't read and write the stack in the same cycle, so do this instead
    reg stack_write_back;
    reg [31:0] stack_write_back_value = 0;

    // TODO: briefly flickers incorrect pushed value on display, because SP has incremented but new value hasn't been written back
    always @(posedge instruction_clock) begin
        led <= ~led;
        instruction_had_32bit_immediate <= 0;

        if (stack_write_back) begin
            stack_write_back <= 0;
            stack[stack_pointer + 1] <= stack_write_back_value;
        end
        else begin
            case (instructions[instruction_index])
                // nop
                8'h00:;

                // halt
                8'hFF: halted <= 1;

                // push {4}
                8'h10: begin
                    instruction_had_32bit_immediate <= 1;

                    stack_pointer = stack_pointer - 1;

                    stack_write_back <= 1;
                    stack_write_back_value <= {
                        instructions[instruction_index+1],
                        instructions[instruction_index+2],
                        instructions[instruction_index+3],
                        instructions[instruction_index+4]
                    };
                end

                // push0
                8'h11: begin
                    stack_pointer = stack_pointer - 1;

                    stack_write_back <= 1;
                    stack_write_back_value <= 0;
                end

                // pop
                8'h02: stack_pointer <= stack_pointer + 1;

                // inc
                8'h20: begin
                    stack_write_back <= 1;
                    stack_write_back_value <= stack_top_item + 1;
                end

                default:;
            endcase
        end
    end

    always @(negedge instruction_clock) begin
        if (~stack_write_back) begin
            if (instruction_had_32bit_immediate)
                instruction_index <= instruction_index + 5;
            else
                instruction_index <= instruction_index + 1;
        end
    end
endmodule
