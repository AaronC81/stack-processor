#!/usr/bin/env ruby

require 'erb'

file = ARGV[0] or abort "Usage: #{$0} <file>"

INSTRUCTIONS = {
    "nop" => { opcode: 0x00 },
    "halt" => { opcode: 0xff },
    "push" => { opcode: 0x10, operand: true },
    "push0" => { opcode: 0x11 },
    "inc" => { opcode: 0x20 },
    "br" => { opcode: 0x30 },
}

bytes = []
File.read(file).split("\n").each.with_index do |line, i|
    error = ->msg{ abort "Error (line #{i + 1}): #{msg}" }

    line.strip!
    next if line.start_with?(';') || line.empty?
    assembly = line.split(";").first
    inst, *operands = *line.split
    error.("No opcode given") if inst.nil?

    inst_info = INSTRUCTIONS[inst] 
    error.("Unknown instruction '#{inst}'") if inst_info.nil?
    opcode = inst_info[:opcode]

    if inst_info[:operand]
        error.("Expected 1 operand, got #{operands.length}") unless operands.length == 1
        operand = operands.first

        case operand.chars[0]
        when 'x'
            operand = Integer(operand[1..], 16)
        when 'd'
            operand = Integer(operand[1..], 10)
        when 'b'
            operand = Integer(operand[1..], 2)
        else
            error.("Malformed operand")
        end
    else
        error.("Operands given but not expected") unless operands.empty?
    end

    bytes << opcode
    unless operand.nil?
        bytes.push(*[operand].pack("N").chars.map(&:ord))
    end
end

puts ERB.new(DATA.read).result(binding)

__END__

// AUTO-GENERATED
// <%= file %>

module instruction_memory(input [31:0] index, output [7:0] instruction, output [31:0] constant);
    wire [7:0] instructions [0:<%= bytes.length - 1 %>];

    <% bytes.each.with_index do |byte, i| %>
    assign instructions[<%= i %>] = 8'h<%= byte.to_s(16) %>;
    <% end %>

    assign instruction = instructions[index];
    assign constant = {
        instructions[index+1],
        instructions[index+2],
        instructions[index+3],
        instructions[index+4]
    };
endmodule
