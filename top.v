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
    main main_inst(
        .CLK(CLK),
        .LED(LED),
        .USBPU(USBPU),
        .PIN_15(PIN_15),
        .PIN_14(PIN_14),
        .PIN_13(PIN_13),
        .PIN_12(PIN_12),
        .PIN_11(PIN_11),
        .PIN_16(PIN_16),
        .PIN_17(PIN_17)
    );
endmodule

module main (
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

    output [31:0] STACK_TOP_ITEM,
    output [31:0] STACK_ITEM_COUNT
);
    // 2^22 * (1 / 16MHz) =~ 0.25s per clock
    parameter INSTRUCTION_CLOCK_BIT = 22;

    parameter STACK_SIZE = 255;

    assign USBPU = 0;

    reg seven_seg_clock;
    seven_seg seven_seg_inst(
        .clk(seven_seg_clock),
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

    // === Stack ===
    // Implements a stack with 32-bit elements which grows downwards.
    //
    // The top and second-from-top (henceforth just "second") items of the stack can be read with
    // `stack_top_item` and `stack_second_item`.
    reg [31:0] stack [0:STACK_SIZE];
    reg [7:0] stack_pointer = STACK_SIZE;

    wire [31:0] stack_top_item;
    assign stack_top_item = stack[stack_pointer + 1];
    assign STACK_TOP_ITEM = stack_top_item;
    wire [31:0] stack_second_item;
    assign stack_second_item = stack[stack_pointer + 2];

    wire stack_is_empty;
    assign stack_is_empty = stack_pointer == STACK_SIZE;
    wire stack_not_empty;
    assign stack_not_empty = ~stack_is_empty;

    assign STACK_ITEM_COUNT = STACK_SIZE - stack_pointer;

    integer i;
    initial begin
        for (i = 0; i <= STACK_SIZE; i = i + 1)
            stack[i] = 0;
    end

    // === Instruction memory ===
    // Access to read-only memory for reading instructions through an index.
    //
    // `inst_instruction` is the byte at the index.
    // `inst_constant` is the 4-byte integer after the current index.
    wire [7:0] inst_instruction;
    wire [31:0] inst_constant;
    reg [31:0] instruction_index = 0;
    instruction_memory instruction_memory_inst(
        .index(instruction_index),
        .instruction(inst_instruction),
        .constant(inst_constant)
    );

    // === Jump control ===
    // By default, on the negative edge of the instruction clock, the instruction index by advance
    // by 1. These controls allow the index to be changed differently on the next negative edge.
    //
    // If `jump_target_set` is 1, then the instruction index will become `jump_target` instead.
    //
    // If `instruction_had_32bit_immediate` is set, then the instruction clock will advance by 5
    // instead of 1.
    reg jump_target_set = 0;
    reg [31:0] jump_target;
    reg instruction_had_32bit_immediate = 0;

    // === Clock divider ===
    // Selects a bit of a counter to use as a clock bit, making this clock available as
    // `instruction_clock`.
    //
    // The clock stops counting up if the processor is `halted`.
    reg [31:0] instruction_clock_counter = 0;
    wire instruction_clock = instruction_clock_counter[INSTRUCTION_CLOCK_BIT];
    reg halted = 0;
    always @(posedge CLK) begin
        if (~halted)
            instruction_clock_counter <= instruction_clock_counter + 1;
    end

    reg led = 0;
    assign LED = led;

    // === Write-back ===
    // Due to memory limitations, it isn't possible to write back to the stack on the same cycle
    // that we execute an instruction. As a result, instructions which write to the stack require
    // an extra cycle to execute.
    //
    // If `stack_write_back` is 1, the next cycle will be spent writing to the stack instead of
    // executing an instruction.
    // `stack_write_back_top_value` is written to the top of the stack.
    //
    // If `stack_write_back_second` is also 1, `stack_write_back_second_value` is written to the
    // second value of the stack.
    reg stack_write_back;
    reg [31:0] stack_write_back_top_value = 0;
    reg stack_write_back_second;
    reg [31:0] stack_write_back_second_value = 0;

    always @(posedge instruction_clock) begin
        led <= ~led;
        jump_target_set <= 0;
        seven_seg_clock <= 0;

        if (stack_write_back) begin
            stack_write_back <= 0;
            stack[stack_pointer + 1] <= stack_write_back_top_value;

            if (stack_write_back_second) begin
                stack_write_back_second <= 0;
                stack[stack_pointer + 2] <= stack_write_back_second_value;
            end
        end
        else begin
            instruction_had_32bit_immediate <= 0;
            case (inst_instruction)
                // nop
                8'h00:;

                // halt
                8'hFF: halted <= 1;

                // push {4}
                8'h10: begin
                    instruction_had_32bit_immediate <= 1;

                    stack_pointer = stack_pointer - 1;

                    stack_write_back <= 1;
                    stack_write_back_top_value <= inst_constant;
                end

                // push0
                8'h11: begin
                    stack_pointer = stack_pointer - 1;

                    stack_write_back <= 1;
                    stack_write_back_top_value <= 0;
                end

                // pop
                8'h02: stack_pointer <= stack_pointer + 1;

                // swap
                8'h03: begin
                    stack_write_back <= 1;
                    stack_write_back_top_value <= stack_second_item;

                    stack_write_back_second <= 1;
                    stack_write_back_second_value <= stack_top_item;
                end

                // inc
                8'h20: begin
                    stack_write_back <= 1;
                    stack_write_back_top_value <= stack_top_item + 1;
                end

                // add
                8'h21: begin
                    stack_write_back <= 1;
                    stack_write_back_top_value = stack_top_item + stack_second_item;

                    stack_pointer = stack_pointer + 1;
                end

                // br
                8'h30: begin
                    jump_target <= stack_top_item;
                    jump_target_set <= 1;
                    stack_pointer <= stack_pointer + 1;
                end

                // show
                8'hFE: seven_seg_clock <= 1;

                default:;
            endcase
        end
    end

    always @(negedge instruction_clock) begin
        if (~stack_write_back) begin
            if (jump_target_set)
                instruction_index <= jump_target;
            else if (instruction_had_32bit_immediate)
                instruction_index <= instruction_index + 5;
            else
                instruction_index <= instruction_index + 1;
        end
    end
endmodule
