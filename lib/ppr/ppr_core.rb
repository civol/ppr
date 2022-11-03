######################################################################
#   Preprocessor in Ruby: preprocessor whose macros are ruby code.  ##
######################################################################

require "ppr/safer_generator.rb"
require "ppr/keyword_searcher.rb"
require 'delegate'

module Ppr


    ## 
    # Converts a +name+ to an attribute symbol.
    def Ppr.to_attribute(name)
        name = name.to_s
        (name.start_with?("@") ? name : "@" + name).to_sym
    end

##
# Describes a storage for line number
class LineNumber < SimpleDelegator
    # Creates a new storage for line number +num+.
    def initialize(num)
        super(num.to_i)
    end

    # Sets the line number to +num+.
    def set(num)
        __setobj__(num.to_i)
    end
end


##
# Describes a macro of the ruby preprocessor.
class Macro

    # The name of the macro.
    attr_reader :name

    # Creates a new macro named +name+, starting at line number +num+,
    # generated from preprocessor +ppr+ and with possible +variables+.
    #
    # Other parameters:
    # +expand+:: used to redefine the expand operator
    # +final+:: indicates that the result of the macro expansion
    # shall not be preprocessed again.
    def initialize(name, num, ppr, *variables, expand: ":<", final: true)
        # Check and set the name.
        @name = name.to_str
        # Check and set the line number of the begining of the macro.
        @start_num = num.to_i
        # Check and set the preprocessor
        unless ppr.is_a?(Preprocessor) then
            raise "Invalid class for a preprocessor: #{ppr.class}"
        end
        @ppr = ppr
        # The start of the macro code is unknown at first (will be known
        # when generating the code).
        @code_num = nil
        # Check and set the variables.
        # print "variables=#{variables}\n"
        @variables = variables.map do |variable|
            variable = variable.to_str
            unless variable.match(/^[a-z_][a-z0-9_]*$/)
                raise "Invalid string for a macro variable: #{variable}"
            end
            variable
        end

        # Initialize the content of the macro as an array of lines.
        @lines = []

        # Set the default expansion operator string.
        @expand = expand

        # Set the macro code expansion result status: when final, no
        # other macro is applied on it, otherwise, it is preprocessed again.
        @final = final ? true : false
    end

    # Converts a +string+ to a quoted string.
    def to_quoted(string)
        return "\"" + 
            string.gsub(/[\"]|#\{/, "\"" => "\\\"", "\#{" => "\\\#{") +
            "\""
            #}}} This comment is just to avoid confusing the text editor.
    end

    # Tells if the maco expansion result is final (i.e., it is not preprocessed
    # again) or not.
    def final?
        return @final
    end

    # Adds a +line+ to the macro.
    def add(line)
        # Process the line.
        # Remove the ending newline if any.
        @lines << line.chomp
    end
    alias << add

    # Checks if the macro is empty (no code line yet).
    def empty?
        return @lines.empty?
    end

    # Generates the code of the macro invoked at line number +i_number+
    # using +values+ for the variables.
    def generate(i_number,*values)
        # First generate a variable for the resulting text.
        result = "result_"
        count = 0
        # Ensure the variable is not used in the code.
        count += 1 while (@lines.find {|line| line.include?(name + count.to_s)})
        result = result + count.to_s
        # The process the lines and join them into the resulting string code.
        buffer = StringIO.new("")
        # Adds the prologue initializing the result text string and setting
        # the values.
        buffer << result + " = StringIO.new(\"\")\n"
        # Update the macro code start line.
        @code_num = 1
        unless @variables.size == values.size
            raise Macro.e_message(@name,
                "invalid number of argument: got #{values.size}, but expecting #{@variables.size}.",i_number,@start_num)
        end
        @variables.each.with_index do |var,i|
            buffer << "#{var} = #{to_quoted(values[i])}\n"
            @code_num += 1
        end
        # Add each line of the macros.
        @lines.each do |line|
            # If any, replace the expand command by a concatenation to the
            # resulting string buffer.
            line = line.sub(@expand,"#{result} << ")
            # Add the line
            buffer << line << "\n"
        end
        # Adds the epilogue
        buffer << result << ".string"
        return buffer.string
    end

    # Methods used by apply for handling exception messages.
    
    # Regular expression for identifying a line number inside an exception
    # message.
    E_NUMBER = /:[1-9][0-9]*:/ 
    # Type of exception which correspond to a macro execution.
    E_TYPE = /\(eval\)\s*/
    
    # Tells if an exception +message+ includes a line number.
    def e_number(message)
        found = E_NUMBER.match(message)
        if found then
            # The number is found, return it.
            return found.to_s[1..-2].to_i
        else
            # The number is not found.
            return nil
        end
    end

    # Tells if an exception message is of a given +type+.
    def e_type?(message,type)
        return message =~ Regexp.new(type)
    end

    # Shifts the line number inside an exception +message+ by +sh+.
    def e_shift_number(message,sh)
        # Edit the message to fix the line number and raise then.
        return message.gsub(E_NUMBER) { |str|
            # Remove the ':'
            str = str[1..-2]
            # Get and check the line number.
            num = str.to_i
            # print "num=#{num}\n"
            if num.to_s == str then
                # This is really a line number.
                ":#{num+sh}:"
            else
                ":#{str}:"
            end
        }
    end

    # Update an exception +message+ to refer macro +name+ invoked at line
    # number +i_number+ and adds a possible macro line +number+.
    def Macro.e_message(name, message, i_number, number = nil)
        result = "Ppr error (#{name}:#{i_number})"
        result << ":#{number}: " if number
        result << message
        return result
    end

    # Update an exception +message+ to refer the macro invoked at line number
    # +i_number+ and adds a possible macro line +number+.
    def e_message(message, i_number, number = nil)
        Macro.e_message(@name,message,i_number,number)
    end

    # Applies the macro invoked at line number +i_number+ with +arguments+.
    def apply(i_number,*arguments)
        # Generate the code of the macro.
        code = self.generate(i_number,*arguments)
        # Evaluate the code in the safe context of ppr.
        # print "code=#{code}\n"
        begin
            return @ppr.run do |__stream__|
                __ppr__ = @ppr
                begin
                    __stream__ << eval(code) 
                # rescue Exception => e
                #     raise e
                end
            end
        rescue Exception => e
            if e.is_a?(SaferGenerator::SaferException) then
                # An exception happened while executing the macro code,
                # get the cause (which contains the exception which has
                # been raised while executing the macro).
                cause = e.cause
                message = cause.message
                # Update the line number in the message if any.
                if e_number(message) then
                    # There is a line number, update it in the context of
                    # the processed file.
                    message = e_shift_number(message, @start_num - @code_num)
                    # Raise the exception again with the updated message.
                    raise cause, e_message(message.gsub(E_TYPE,""),i_number)
                else
                    # There was not any line number in the message, look
                    # for it into the backtrack message.
                    number = cause.backtrace.find do |trace|
                        found = e_number(trace)
                        if found and e_type?(trace,E_TYPE)
                            break found
                        else
                            next nil
                        end
                    end
                    if number then
                        # Update the line number in the context of the processed
                        # file.
                        number += @start_num - @code_num
                        # The number found, raise the exception again with
                        # the message updated with the number.
                        raise cause,
                            e_message(message.gsub(E_TYPE,""),i_number,number)
                    else
                        # No number, use the macro start instead for
                        # raising the exception.
                        raise cause, e_message(message,i_number,@start_num)
                    end
                end        
            else
                # An exception happened due to an internal error of the
                # SaferGenerator class, raise it as is.
                raise e
            end
        end
    end

end


## 
# Describes an assignment macro of the ruby preprocessor.
class Assign < Macro
    # Creates a new assignment macro whose assigned variable is +var+,
    # starting at line number +num+ generated from preprocessor +ppr+.
    # 
    # Other parameters:
    # +expand+:: redefines the expand operator string.
    def initialize(name, num, ppr, expand: ":<")
        super(name,num,ppr,expand: expand)
        # Creates the attribute which will be assigned.
        @var_sym = Ppr.to_attribute(name)
    end

    # Applies the macro invoked at line number +i_number+,
    # its result in assigned to the class variable.
    def apply(i_number)
        # Expands the macro.
        line = super(i_number)
        # Assign the result to the variable.
        @ppr.parameter_set(@var_sym,line)
        # No modification of the output file, so return an empty string.
        return ""
    end
end

## 
# Descibes an abstract class for loading or requiring files.
class LoadRequire < Macro
    # Creates a new load or require macro starting at line number +num+
    # generated from preprocessor +ppr+.
    # 
    # The +expand+ strings be redefined through keyword arguments.
    def initialize(num, ppr, expand: ":<")
        super("",num,ppr,expand: expand)
    end

    def set_locations(locations)
        @locations = locations
    end

    def find_file(name)
        @locations.each do |i|
          filepath =  i + "/" + name
          if File.exist?(filepath)
            return filepath
          end
        end

        raise "File #{name} was not found in includes."
    end

    # Loads and preprocess file +name+.
    def loadm(name)
        output = StringIO.new("")
        # print "name=#{name}\n"
        File.open(find_file(name),"r") do |input|
            @ppr.preprocess(input,output)
        end
        return output.string
    end
end

##
# Describes a macro loading and pasting a file into the current one.
class Load < LoadRequire
    # Applies the macro invoked at line number +i_number+,
    # its result is the name of the file to be loaded.
    def apply(i_number)
        # Expand the macro, its result is the name of the file to load.
        name = super(i_number)
        # print "Loading file: #{name}\n"
        # Load and preprocess the file.
        # return File.read(name)
        return loadm(name)
    end
end

# Describes a macro loading and pasting a file into the current one
# only if it has not already been loaded before.
class Require < LoadRequire
    @@required = [] # The already required files.

    # Applies the macro invoked at line number +i_number+,
    # its result is the name of the file to be loaded if not already loaded.
    def apply(i_number)
        # Expand the macro, its result is the name of the file to load.
        name = super(i_number)
        # Has it already been required?
        unless @@required.include?(name) then
            # No, mark it as required and load and preprocess the file.
            @@required << name
            # return File.read(name)
            return loadm(name)
        else
            # Yes, nothing to do.
            return ""
        end
    end
end

##
# Describes a conditional macro.
class If < Macro
    # Creates a new load or require macro starting at line number +num+
    # generated from preprocessor +ppr+.
    # 
    # The +expand+ strings be redefined through keyword arguments.
    def initialize(num, ppr, expand: ":<")
        super("",num,ppr,expand: expand)
    end
end


##
# Describes the ruby preprocessor.
#
# Usage:
#         ppr = Ppr::Preprocessor.new(<some options>)
#         ppr.preprocess(<some input stream>, <some output stream>)
class Preprocessor

    # Creates a new preprocessor, where +apply+, +applyR+, +define+, +defineR+,
    # +assign+, +loadm+, +requirem+, +ifm+, +elsem+ and +endm+ are the
    # keywords defining the beginings and end of a macro definitions,
    # and where +separator+ is the regular expression used for
    # separating macro references to the remaining of the code, +expand+ is
    # the string representing the expansion operator of the macro, +glue+ is
    # string used for glueing a macro expension to the text,
    # +escape+ is the escape character.
    #
    # Assigned parameters can be added through +param+ to be used within 
    # the macros of the preprocessed text.
    def initialize(params = {},
                   apply: ".do", applyR: ".doR", 
                   define: ".def", defineR: ".defR",
                   assign: ".assign",
                   loadm: ".load", requirem: ".require",
                   ifm: ".if", elsem: ".else", endifm: ".endif",
                   endm: ".end",
                   expand: ":<",
                   separator: /^|[^\w]|$/, glue: "##",
                   escape: "\\",
                   includes: Dir.pwd)
        # Check and Initialize the keywords
        # NOTE: since there are a lot of checks, use a generic but
        # harder to read code.
        keys = [ "apply", "applyR", "define", "defineR", "assign",
                 "loadm", "requirem", "ifm", "elsem", "endifm", "endm"]
        # Sort the keywords by string content to quickly find erroneously
        # identical ones.
        keys.sort_by! {|key| eval(key) }
        # Check for identical keywords.
        keys.each_with_index do |key,i|
            value = eval(key)
            if i+1 < keys.size then
                # Check if the next keyword has the same string.
                nvalue = eval(keys[i+1])
                if value == nvalue then
                    # Two keywords with same string.
                    raise "'#{key}:#{value}' and '#{keys[i+1]}:#{nvalue}' keywords must be different."
                end
            end
        end

        # Seperate the begin of macro keywords from the others (they
        # are used differently).
        other_keys = ["elsem", "endifm", "endm"]
        begin_keys = keys - other_keys
        # Assign the begin of macro keywords to the corresponding attributes.
        begin_keys.each do |key|
            eval("@#{key} = #{key}.to_s")
        end
        # Generates the structures used for detecting the keywords.
        # For the begining of macros.
        @macro_keys = (begin_keys - other_keys).map do
            |key| self.instance_variable_get("@#{key}")
        end.sort!.reverse
        # For the other keywords.
        other_keys.each do |key|
            eval('@'+key+' = Regexp.new("^\s*#{Regexp.escape('+key+')}\s*$")')
        end

        # Sets the expand command.
        @expand = expand.to_s
        # Check and set the separator, the glue and the escape.
        @separator = Regexp.new("(?:#{separator}|#{glue})")
        @glue = glue.to_s

        # Initialize the current line number to 0.
        @number = LineNumber.new(0)
        # Initialize the macros.
        @macros = KeywordSearcher.new(@separator)

        # Initialize the stack for handling the if macros.
        @if_mode = []

        # Create the execution context for the macros.
        @generator = SaferGenerator.new
        @context = Object.new
        # Process the preprocessing parameters.
        params.each do |k,v|
            parameter_set(k,v)
        end

        #include folder locations to search for load and require
        @includes = []
        (@includes << includes).flatten!
    end

    # Methods for handling the execution context of the macros.

    # Executes a macro in a safe context.
    def run(&proc)
        @generator.run do |__stream__|
            @context.instance_exec(__stream__,&proc) 
        end
    end

    # Sets parameter +param+ to +value+.
    def parameter_set(param,value)
        # print "Setting #{Ppr.to_attribute(param)} with #{value.to_s}\n"
        @context.instance_variable_set(Ppr.to_attribute(param),value.to_s)
    end

    # Gets the value of parameter +param.
    def parameter_get(param)
        return @context.instance_variable_get(Ppr.to_attribute(param))
    end

    # Methods for parsing the lines.
    
    # Restores a +string+ whose begining may have been glued.
    def unglue_front(string)
        if string.start_with?(@glue) then
            # There is a glue, so remove it.
            string = string[@glue.size..-1] 
        elsif string.start_with?("\\") then
            # There is an escape, so remove it.
            string = string[1..-1]
        end
        return string
    end

    # Restores a +string+ whose ending may have been glued.
    def unglue_back(string)
        if string.end_with?(@glue) then
            # There is a glue, so remove it.
            string = string[0..(-@glue.size-1)] 
        elsif string.end_with?("\\") then
            # There is an escape, so remove it.
            string = string[0..-2]
        end
        return string
    end

    # Gets the range of an argument starting at offset +start+ in +line+.
    def get_argument_range(line, start)
        if start >= line.size then
            raise "incomplete arguments in macro call."
        end
        range = line[start..-1].match(/(\\\)|\\,|[^\),])*/).offset(0)
        return (range[0]+start)..(range[1]+start-1)
    end

    # Iterates over the range each argument of a +line+ from offset +start+.
    #
    # NOTE: keywords included into a longer one are ignored.
    def each_argument_range(line,start)
        return to_enum(:each_argument_range,line,start) unless block_given?
        begin
            # Get the next range
            range = get_argument_range(line,start)
            if range.last >= line.size then
                raise "invalid line for arguments: #{line}"
            end
            # Apply the block on the range.
            yield(range)
            # Prepares the next range.
            start = range.last + 2
        end while start > 0 and line[start-1] != ")"
    end


    # Tells if a line corresponds to an end keyword.
    def is_endm?(line)
        @endm.match(line.strip)
    end

    # Tells if a line corresponds to an else keyword.
    def is_elsem?(line)
        @elsem.match(line.strip)
    end

    # Tells if a line corresponds to an endif keyword.
    def is_endifm?(line)
        @endifm.match(line.strip)
    end

    # Extract a macro definition from a +line+ if there is one.
    def get_macro_def(line)
        line = line.strip
        # Locate and identify the macro keyword.
        macro_type = @macro_keys.find { |mdef| line.start_with?(mdef) }
        return nil unless macro_type
        line = line[(macro_type.size)..-1]
        if /^\w/.match(line) then
            # Actually the line was starting with a word including @define,
            # this is not a real macro definition.
            return nil
        end
        # Sets the flags according to the type.
        final = (macro_type == @define or macro_type == @apply) ? true : false
        named = (macro_type == @define or macro_type == @defineR or
                 macro_type == @assign) ? true : false
        # Process the macro.
        line = line.strip
        if named then
            # Handle the case of named macros.
            # Extract the macro name.
            name = /[a-zA-Z_]\w*/.match(line).to_s
            if name.empty? then
                # Macro with no name, error.
                raise Macro.e_message(""," macro definition without name.",
                                      @number)
            end
            line = line[name.size..-1]
            line = line.strip
            # Extract the arguments if any
            # print "line=#{line}\n"
            par = /^\(\s*[a-zA-Z_]\w*\s*(,\s*[a-zA-Z_]\w*\s*)*\)/.match(line)
            if par then
                if macro_type == @assign then
                    # Assignment macro: there should not be any argument.
                    raise Macro.e_message(""," assignement with argument.",
                                          @number)
                end
                # There are arguments, process them.
                par = par.to_s
                # Extract them
                arguments = par.scan(/[a-zA-Z_]\w*/)
                line = line[par.size..-1].strip
            else
                # Check if there are some invalid arguments
                if line[0] == "(" then
                    # Invalid arguments.
                    raise Macro.e_message(name,
                            " invalid arguments for macro definition.", @number)
                end
                # No argument.
                arguments = []
            end
        else
            # Handle the case of unnamed macros.
            name = ""
        end
        case macro_type
        when @assign then
            macro = Assign.new(name,@number,self,expand: @expand)
        when @loadm then
            macro = Load.new(@number,self,expand: @expand)
            macro.set_locations(@includes)
        when @requirem then
            macro = Require.new(@number,self,expand: @expand)
            macro.set_locations(@includes)
        when @ifm then
            macro = If.new(@number,self,expand: @expand)
        else
            macro = Macro.new(name,@number,self,
                              *arguments,final: final,expand: @expand) 
        end
        # Is it a one-line macro?
        unless line.empty? then
            # Yes, adds the content to the macro.
            macro << line
        end
        return macro
    end


    # Applies recursively each element of +macros+ to +line+.
    #
    # NOTE: a same macro is apply only once in a portion of the line.
    def apply_macros(line)
        # print "apply_macros on line=#{line}\n"

        # Initialize the expanded line.
        expanded = ""
        
        # Look for a first macro.
        macro,range = @macros.find(line)
        while macro do
            # print "macro.name=#{macro.name}, range=#{range}\n"
            # If the are some arguments, extract them and cut the macro
            # of the line.
            if range.first > 0 then
                sline = [ line[0..(range.first-1)] ] 
            else
                sline = [ "" ]
            end
            if line[range.last+1] == "(" then
                # print "Before line=#{line}\n"
                last = range.last+1 # Last character position of the arguments
                begin
                    sline +=   
                    each_argument_range(line,range.last+2).map do |arg_range|
                        last = arg_range.last
                        apply_macros(line[arg_range])
                    end
                rescue Exception => e
                    # A problem occurs while extracting the arguments.
                    # Re-raise it after processing its message.
                    raise e, macro.e_message(" " + e.message,@number)
                end
                range = range.first..(last+1)
            end
            if range.last + 1 < line.size then
                sline << line[(range.last+1)..-1]
            else
                sline << ""
            end
            # print "After sline=#{sline}\n"
            result = macro.apply(@number,*(sline[1..-2]))
            # print "Macro result=#{result}, sline[0]=#{sline[0]} sline[-1]=#{sline[-1]}\n"
            # Recurse on the modified portion of the line if the macro
            # requires it
            result = apply_macros(result) unless macro.final?
            # print "Final expansion result=#{result}\n"
            # Join the macro expansion result to the begining of the line
            # removing the possible glue string.
            expanded += unglue_back(sline[0]) + result
            # print "expanded = #{expanded}\n"
            # The remaining is to treat again after removing the possible
            # glue string
            line = unglue_front(sline[-1])
            # Look for the next macro
            macro,range = @macros.find(line)
        end
        # Add the remaining of the line to the expansion result.
        expanded += line
        # print "## expanded=#{expanded}\n"
        return expanded
    end

    # Close a +macro+ being input registering it if named or applying it
    # otherwise.
    #  
    # NOTE: for internal use only.
    def close_macro(macro)
        # Is the macro named?
        unless macro.name.empty? or macro.is_a?(Assign) then
            # Yes, register it.
            @macros[macro.name] = macro
            # Return an empty string since not to be applied yet.
            return ""
        else
            # No, apply it straight away.
            line = macro.apply(@number)
            # Shall we process again the result?
            unless macro.final? then
                # print "Not final, line=#{line}.\n"
                # Yes.
                line = apply_macros(line)
            end
            if macro.is_a?(If) then
                # The macro was an if condition, is the result false?
                if line.empty? or line == "false" or line == "nil" then
                    # Yes, enter in skip_to_else mode which will skip the text
                    # until the next corresponding else keyword.
                    @if_mode.push(:skip_to_else)
                else
                    # No, enter in keep to else mode which process the text
                    # normally until the next corresponding else keyword.
                    @if_mode.push(:keep_to_else)
                end
                # The condition is not to keep.
                return ""
            else
                return line
            end
        end
    end
    private :close_macro

    # Preprocess an +input+ stream and write the result to an +output+
    # stream.
    def preprocess(input, output)
        # # The current list of macros.
        # @macros = KeywordSearcher.new(@separator)

        # The macro currently being input.
        cur_macro = nil

        # Process the input line by line
        input.each_line.with_index do |line,i|
            @number.set(i+1)
            # check if the line is to skip.
            if @if_mode[-1] == :skip_to_else then
                # Skipping until next else...
                if is_elsem?(line) then
                    # And there is an else, enter in keep to endif mode.
                    @if_mode[-1] = :keep_to_endif
                end
                next # Skip.
            elsif @if_mode[-1] == :keep_to_else then
                # Keeping until an else is met.
                if is_elsem?(line) then
                    # And there is an else, enter in skip to endif mode.
                    @if_mode[-1] = :skip_to_endif
                    # And skip current line since it is a keyword.
                    next
                elsif is_endifm?(line) then
                    # This is the end of the if macro.
                    @if_mode.pop
                    # And skip current line since it is a keyword.
                    next
                end
            elsif @if_mode[-1] == :skip_to_endif then
                # Skipping until next endif.
                if is_endifm?(line) then
                    # And there is an endif, end the if macro.
                    @if_mode.pop
                end
                next # Skip
            elsif @if_mode[-1] == :keep_to_endif then
                if is_endifm?(line)
                @if_mode.pop
                    # And there is an endif, end the if macro.
                    @if_mode.pop
                    # And skip current line since it is a keyword.
                    next
                end
            end
            # No skip.

            # Check if there are invalid elsem or endifm
            if is_elsem?(line) then
                raise Macro.e_message( "invalid #{@elsem} keyword.",@number)
            elsif is_endifm?(line) then
                raise Macro.e_message( "invalid #{@endifm} keyword.",@number)
            end

            # Is a macro being input?
            if cur_macro then
                # Yes.
                if get_macro_def(line) then
                    # Yet, there is a begining of a macro definition: error
                    raise cur_macro.e_message(
                      "cannot define a new macro within another macro.",@number)
                end
                # Is the current macro being closed?
                if is_endm?(line) then
                    # Yes, close the macro.
                    output << close_macro(cur_macro)
                    # The macro ends here.
                    cur_macro = nil
                else
                    # No add the line to the current macro.
                    cur_macro << line
                end
            else
                # There in no macro being input.
                # Check if a new macro definition is present.
                cur_macro = get_macro_def(line)
                if cur_macro and !cur_macro.empty? then
                    # This is a one-line macro close it straight await.
                    output << close_macro(cur_macro)
                    # The macro ends here.
                    cur_macro = nil
                    next # The macro definition is not to be kept in the result
                end
                next if cur_macro # A new multi-line macro definition is found,
                                  # it is not to be kept in the result.
                # Check if an end of multi-line macro defintion is present.
                if is_endm?(line) then
                    # Not in a macro, so error.
                    raise Macro.e_message("",
                        "#{@endm} outside a macro definition.",@number)
                end
                # Recursively apply the macro calls of the line.
                line = apply_macros(line)
                # Write the line to the output.
                # print ">#{line}"
                output << line
            end
        end
    end
end




# Might be useful later, so kept as comment...
# ## Methods for parsing lines for macro processing.
# module LineParsing
# 
#     ## Processes a +string+ for becoming a valid argument.
#     #  
#     #  Concreatly, escapes the characters which have a function in an
#     #  argument list (e.g., ',', '(').
#     def to_argument(string)
#         return string.gsub(/[,\\)]/, "," => "\\,", "\\" => "\\\\", ")" => "\\)")
#     end
# 
#     ## Restores a +string+ escaped to be a valid argument.
#     def to_unargument(string)
#         return string.gsub("\\\\", "\\")
#     end
# end




end
