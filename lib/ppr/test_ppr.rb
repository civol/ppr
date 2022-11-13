######################################################################
##                          Program testing Ppr                     ##
######################################################################

require "ppr.rb"
require 'stringio'

# Function for testing a preprocessor
def test_preprocessor(preprocessor,input,expected)
    # Prepare the output and the input streams
    puts "Preparing the input and ouput streams..."
    output = StringIO.new("")
    # Process the input and exepected arguments.
    if !input.respond_to?(:each_line) or input.is_a?(String) then
        # input is actually a file name, open it.
        input = File.open(input.to_s,"r")
    end
    if !expected.respond_to?(:each_line) or expected.is_a?(String) then
        # expected is actually a file name, open it.
        expected = StringIO.new(File.read(expected.to_s))
    end

    # Apply the preprocessor
    puts "Applying the preprocessor..."
    preprocessor.preprocess(input,output)

    # Check the result
    puts "Checking the result..."
    output.rewind
    check = output.string == expected.read

    unless check
        puts "*Error*: invalid expansion result."
        iline = output.string.each_line
        expected.rewind
        expected.each_line.with_index do |exp_line,i|
            line = iline.next
            puts "exp_line=#{exp_line}"
            puts "line=#{line}"
            if exp_line != line then
                puts "Expected line #{i+1}:\n#{exp_line}"
                puts "got:\n#{line}"
            end
        end
        return false
    end
    return true
end

# Function for testing a preprocessor on +string+ which should raise an 
# +exception+ string.
def test_preprocessor_exception(preprocessor,string,exception)
    input = StringIO.new(string)
    output = StringIO.new("")
    begin
        $ppr.preprocess(input,output)
        puts "*Error*: preprocessed without exception."
        return false
    rescue Exception => e
        if e.to_s.include?(exception.to_s) then
            puts "Got exception: <#{e}> as expected."
            return true
        else
            puts "*Error*: unexpected exception.", 
                 "Got <#{e}> but expecting <#{exception}>."
            return false
        end
    end
end

# Test the default preprocessor

puts "Building the default preprocessor with one expansion parameter..."
$ppr = Ppr::Preprocessor.new({"hello" => "Hello"})
puts "Testing it..."
$success = test_preprocessor($ppr,"#{File.dirname(__FILE__)}/test_ppr.txt",
                                  "#{File.dirname(__FILE__)}/test_ppr_exp.txt")

# if $success then
#     puts "Success." 
# else
#     puts "Failure."
# end
# exit

puts "\nBuilding a preprocessor with redefined keywords and one expansion parameter."
$ppr1 = Ppr::Preprocessor.new({hello: "Hello"},
                              apply: "RUBY", applyR: "RUBYR",
                              define: "MACRO", defineR: "MACRO_R",
                              assign: "ASSIGN",
                              endm: "ENDM", 
                              expand: "~>", separator: /^|[^\w]|$/, glue: "@@")
puts "Testing it..."
$success &= test_preprocessor($ppr1,"#{File.dirname(__FILE__)}/test_ppr2.txt",
                                   "#{File.dirname(__FILE__)}/test_ppr_exp.txt")

puts "Testing invalid proprocessor with identical strings for different keywords...."
begin
    ppr = Ppr::Preprocessor.new(apply: "APPLY", applyR: "APPY_R", 
                                define:"APPLY")
    # Should not be there.
    puts "*Error*: preprocessor built with invalid arguments did not raise any expcetion."
    $success = false
rescue Exception => e
    puts "Got exception as expected: #{e.to_s}."
end


puts  "\nTesting invalid macro definitions..."
print "... Unfinished macro... "
$success &= test_preprocessor_exception($ppr, ".def\n :< 'Hello' \n",
                                        ":1) macro definition without name.")

print "... Incomplete arguments... "
$success &= test_preprocessor_exception($ppr, 
                                     "\n.def HE(\n :< 'Hello' \n.end\n",
                                     ":2) invalid arguments for macro definition.")

puts  "\nTesting invalid macro call..."
print "... Unfinished macro call case #0... "
$success &= test_preprocessor_exception($ppr, 
                        "\n\n.def HE(name)\n :< 'Hello ',name \n.end\nHE(",
                        "HE:6) incomplete arguments in macro call.")
print "... Unfinished macro call case #1... "
$success &= test_preprocessor_exception($ppr, 
                        "\n.def HE(name)\n :< 'Hello ',name \n.end\nHE(A",
                        "HE:5) incomplete arguments in macro call.")
print "... Unfinished macro call case #2... "
$success &= test_preprocessor_exception($ppr, 
                        ".def HE(name)\n :< 'Hello ',name \n.end\nHE(A,",
                        "HE:4) incomplete arguments in macro call.")
print "... Unfinished macro call case #3... "
$success &= test_preprocessor_exception($ppr, 
                        "\n.def HE(name)\n :< 'Hello ',name \n.end\nHE(A,B",
                        "HE:5) incomplete arguments in macro call.")
print "... macro call with too many arguments... "
$success &= test_preprocessor_exception($ppr, 
                        "\n.def HE(name)\n :< 'Hello ',name \n.end\nHE(A,B)",
                        "HE:5):2: invalid number of argument: got 2, but expecting 1")

puts  "\nTesting call of macro with invalid code..."
print "... Syntax error in macro code... "
$success &= test_preprocessor_exception($ppr, 
                        "\n\n\n.def HE(name)\n :< 1,2 \n.end\nHE(Foo)",
                        "HE:7):5: syntax error")
print "... Division by zero in macro code... "
$success &= test_preprocessor_exception($ppr, 
                        "\n.def HE(name)\n :< 1/0 \n.end\nHE(Foo)",
                        "HE:5):3: divided by 0")
print "... Undefined symbol in macro code... "
$success &= test_preprocessor_exception($ppr, 
                        "\n.def HE(name)\n :< foobar \n.end\nHE(Foo)",
                        "HE:5):3: undefined local variable or method")


# puts "\nBuilding a preprocessor with an invalid escape character."
# $raised = false
# begin
#     $ppr = Ppr::Preprocessor.new(escape: "HA")
# rescue Exception => e
#     puts "As expected an exception has been raised (#{e.inspect})."
#     $raised = true
# end
# unless $raised then
#     puts "Error: an exception should have been raised."
#     $success = false
# end


puts "\n\nNow going to Test the examples of the documentation."
puts "Testing example 1..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 1:
.do
   :< "Hello world!"
.end'
), StringIO.new(
'Example 1:
Hello world!') )

puts "\nTesting example 2..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 2:
.def hello(world)
   :< "Hello #{world}!"
.end
hello(Foo)
hello( Bar )'
), StringIO.new(
'Example 2:
Hello Foo!
Hello  Bar !') )

puts "\nTesting example 3..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 3:
.def hello(world) :< "Hello #{world}!"
.doR
   :< "hello(WORLD)"
.end'
), StringIO.new(
'Example 3:
Hello WORLD!') )

puts "\nTesting example 4..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 4:
.defR sum(num)
   num = num.to_i
   if num > 2 then
      :< "(+ sum(#{num-1}) #{num} )"
   else
      :< "(+ 1 2 )"
   end
.end
Some lisp: sum(5)'
), StringIO.new(
'Example 4:
Some lisp: (+ (+ (+ (+ 1 2 ) 3 ) 4 ) 5 )') )

puts "\nTesting example 5..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 5:
.assign he :< "Hello"
.do :< @he + " world!\n"
.def hehe :< @he+@he
hehe'
), StringIO.new(
'Example 5:
Hello world!
HelloHello') )

puts "\nTesting example 6..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 6:
.load :< "foo.inc"
.def foo :< "FooO"
.load :< "foo.inc"'
), StringIO.new(
'Example 6:
foo and bar
FooO and bar
') )

# Rebuild ppr to avoid conflict with example 6.
$ppr = Ppr::Preprocessor.new
puts "\nTesting example 7..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 7:
.require :< "foo.inc"
.def foo :< "FooO"
.require :< "foo.inc"'
), StringIO.new(
'Example 7:
foo and bar
') )

puts "\nTesting example 8..."
$success &= test_preprocessor($ppr,
  StringIO.new(
'Example 8:
.if :< (1 == 1)
.def is :< "IS"
This is true.
.else
This is false.
.endif
.if :< (1 == 0)
This is really true.
.else
This is really false.
.endif'
), StringIO.new(
'Example 8:
This IS true.
This IS really false.
') )



if $success then
    puts "Success." 
else
    puts "Failure."
end
