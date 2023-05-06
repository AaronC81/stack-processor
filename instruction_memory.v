module instruction_memory(input [31:0] index, output [7:0] instruction, output [31:0] constant);
    wire [7:0] instructions [0:7];
    assign instructions[0] = 8'h10; // push
    assign instructions[1] = 8'h00; //   xx000000
    assign instructions[2] = 8'h00; //   00xx0000
    assign instructions[3] = 8'h00; //   0000xx00
    assign instructions[4] = 8'h06; //   000000xx
    assign instructions[5] = 8'h20; // inc
    assign instructions[6] = 8'h20; // inc
    assign instructions[7] = 8'hFF; // halt

    assign instruction = instructions[index];
    assign constant = {
        instructions[index+1],
        instructions[index+2],
        instructions[index+3],
        instructions[index+4]
    };
endmodule
