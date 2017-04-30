######################################################################
##                   Program testing SaferGenerator                 ##
######################################################################

require "ppr.rb"

# Create the generator
puts "Creating the generator..."
$generator = SaferGenerator.new

puts "Creating the procs to test..."
# Create the safe proc to test.
$safe = proc { |stream| stream << 10.times.to_a.join(", ") }
# Create the unsafes proc to test.
$unsafes = []
$unsafes << proc { |stream| File.open("bad.bad","w") {|file| file << "Bad\n" } }
$unsafes << proc { |stream| stream << "Going to dir..." << Dir["./*"] }
$unsafes << proc { |stream| stream << IO.binread(__FILE__) }
$unsafes << proc { |stream| stream << system("ls") }
$unsafes << proc { |stream| stream << `ls` }
$unsafes << proc { |stream| open("bad.bad","w") { |file| file << "Bad\n" } }
# Create the expected raised exceptions with the unsafe procs.
$exceptions = [ NameError, NameError, NameError, NoMethodError, NoMethodError,
                NoMethodError ]

ok = true # Test result, true if not any trouble.

# Test the execution of safe code for generating text.
$expected = StringIO.new("")
$safe.call($expected)
$expected = $expected.string
$result = ""
print "Executing safe code..."
begin
    $result = $generator.run(&$safe)
rescue Exception => e
    puts "\nError: got exception #{e}"
    ok = false
end
if ok then
    if $expected == $result then
        ok = true
    else
        ok = false
        puts "\nError: unexpected execution result."
        puts "Got #{$result} but expecting #{expected}."
    end
end
puts " ok.\n" if ok

# Test the execution of the unsafe code.
$unsafes.each.with_index do |unsafe,i|
    print "Executing unsafe proc #{i}..."
    begin
        $result = $generator.run(&unsafe)
        # Should not execute the following.
        puts " Danger: the unsafe code should not have been executed."
        ok = false
    rescue Exception => e
        if e.cause.class != $exceptions[i] then
            puts " Danger: unexpected exception: #{e.cause.inspect}"
            ok = false
        end
        puts " Safe: got exception #{e.cause.inspect} as expected."
    end
end


# Now check the black list.

# Create a new safer generator with a blacked list methods or constants.
$blacks = [ :print, :Float ]
# Create the procs using black lists methods or constants.
$unsafes = []
$unsafes << proc { |stream| print "Should not work..." }
$unsafes << proc { |stream| Float.name }
# Create the expected exceptions.
$exceptions = [ NoMethodError, NameError ]

# Check each black listed element.
$blacks.each.with_index do |black,i|
    puts "Creating a safer generator where '#{black}' is blacked list..."
    $generator = SaferGenerator.new(black)
    puts "Executing safe code..."
    begin
        $result = $generator.run(&$safe)
    rescue Exception => e
        puts "\nError: got exception #{e}"
        ok = false
    end
    puts "Executing code with #{black}..."
    begin
        $result = $generator.run(&$unsafes[i])
        # The following should not be executed.
        puts " Danger: '#{black}' should not have been executed."
        ok = false
    rescue Exception => e
        if e.cause.class == $exceptions[i] then
            puts " Safe: got exception #{e.cause.inspect} as expected."
        else
            puts " Danger: unexpected exception #{e.cause.inspect}."
            ok = false
        end
    end
end

# Check with all the black list elements.
puts "Creating a safer generator where '#{$blacks}' are blacked list..."
$generator = SaferGenerator.new(*$blacks)
puts "Executing safe code..."
begin
    $result = $generator.run(&$safe)
rescue Exception => e
    puts "\nError: got exception #{e}"
    ok = false
end
# Check each unsafe proc.
$unsafes.each.with_index do |unsafe,i|
    puts "Executing code #{i}..."
    begin
        $result = $generator.run(&unsafe)
        # The following should not be executed.
        puts " Danger: the proc should not have been executed."
        ok = false
    rescue Exception => e
        if e.cause.class == $exceptions[i] then
            puts " Safe: got exception #{e.cause.inspect} as expected."
        else
            puts " Danger: unexpected exception #{e.cause.inspect}."
            ok = false
        end
    end
end


if ok then
    puts "Success." 
else
    puts "Failure." 
end
