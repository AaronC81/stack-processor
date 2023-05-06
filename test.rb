# Our tests use `apio sim`, which will open `gtkwave` after every simulation
# We don't want to do that!
# Create a stub executable in /tmp called `gtkwave`, and add it to the PATH, so this attempt does
# nothing instead
require 'fileutils'
stub_dir_path = "/tmp/gtkwave-stub"
stub_path = File.join(stub_dir_path, "gtkwave")
FileUtils.mkdir_p(stub_dir_path)
ENV["PATH"] = "#{stub_dir_path}:#{ENV["PATH"]}"
File.write(stub_path, "#!/bin/sh\necho Nothing here...")
`chmod +x "#{stub_path}"`

# Discover all tests
Test = Struct.new('Test', :file, :name, :assertions)
tests = []
Dir[File.join(__dir__, "programs", "*.asm")].each do |file|
    contents = File.read(file)
    next unless contents.include?(";!test")

    # Parse assertion expressions
    assertions = []
    contents.split("\n").each do |line|
        next unless line.strip.start_with?(";!assert ")
        _, expr = line.strip.split(/\s+/, 2)
        assertions << expr
    end

    abort "Error: #{file} has no assertions" if assertions.empty?

    tests << Test.new(file, File.basename(file, ".asm"), assertions)
end
puts "Discovered #{tests.length} tests:"
puts tests.map { |f| "  - #{f.name} (#{f.assertions.length} assertions)" }

# Run tests
tests_with_results = tests.map do |t|
    puts
    puts "=== Running: #{t.name} ==="

    # Assemble code
    print "Assemble"
    asm_out = `ruby assemble.rb "#{t.file}"`
    File.write(File.join(__dir__, "instruction_memory.v"), asm_out)
    unless $?.success?
        puts "\nERROR"
        puts asm_out
        next [t, false]
    end

    # Run simulation
    print " | Simulate"
    sim_out = `apio sim`
    unless $?.success?
        puts "\nERROR"
        puts sim_out
        next [t, false]
    end

    # Load results
    print " | Load"
    begin
        top = nil
        count = nil
        eval(File.read(File.join(__dir__, "top_tb_data.rb")), binding)
    rescue => e
        puts "\nERROR"
        p e
        next [t, false]
    end

    # Check assertions
    puts " | Check"
    all_assertions_ok = t.assertions.all? do |assert|
        puts "  #{assert}"
        result = eval(assert, binding)
        if result != true
            puts "  ASSERTION FAILED"
            false
        else
            true
        end
    end

    if all_assertions_ok
        puts "PASSED"
    end

    [t, all_assertions_ok]
end
