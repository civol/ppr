# require 'yaml'

######################################################################
#                        Safer string generator.                     #
######################################################################


# Tool for executing in a safer sandbox a proc that generates a string into a
# stream.
class SaferGenerator

    # The exception raised when the safer processed failed.
    class SaferException < RuntimeError
    end

    # The list of dangerous constants of Object.
    DANGER_CONSTANTS = [ :File, :IO, :Dir ]

    # The list of dangerous methods of Kernel
    DANGER_METHODS  = [ :system, :`, :open ]


    # Creates a new safe context with while removing Kernel methods and
    # constants from +black_list+ in addition to the default dangerous
    # ones.
    def initialize(*black_list)
        # Set the black list of methods.
        @black_methods = black_list.select do |symbol|
            symbol.to_s[0].match(/[a-z_]/)
        end
        # Set the black list of constants.
        @black_constants = black_list.select do |symbol|
            symbol.to_s[0].match(/[A-Z]/)
        end
    end

    # Strips all the Kernel methods and constants appart from the
    # elements of the white list.
    # Also strip Object from dangerous methods and constants apart
    # from the elements of the white list.
    def secure
        # Gather the methods to strip.
        methods = DANGER_METHODS + @black_methods
        # Gather the constants to strip.
        constants = DANGER_CONSTANTS + @black_constants
        # Save the dangerous methods in a private safe.
        @safe_of_methods = {}
        methods.each do |meth|
            @safe_of_methods[meth]=method(meth)
        end
        # Save the dangerous constants in a private safe.
        @safe_of_constants = {}
        constants.each do |cst|
            @safe_of_constants[cst] = Object.send(:const_get,cst)
        end
        # Strip the dangerous methods.
        methods.each do |meth|
            Kernel.send(:undef_method,meth)
        end
        # Strip the dangerous constants from Object.
        constants.each do |cst|
            Object.send(:remove_const,cst)
        end
    end

    # Restores all the stripped Kernel methods and constants appart from the
    # elements of the white list.
    # Also strip Object from dangerous methods and constants apart
    # from the elements of the white list.
    def unsecure
        # Restores the dangerous methods in a private safe.
        @safe_of_methods.each do |(name,pr)|
            Kernel.send(:define_method,name,&pr)
        end
        # Restors the dangerous constants in a private safe.
        @safe_of_constants.each do |(name,cst)|
            Object.const_set(name,cst)
        end
    end


    # Executes +block+ in a safe context for  generating text into a +stream+.
    #
    # If no stream is given, returns the result as a string instead.
    def run(stream = nil, &block)
        unless stream
            # No stream given
            to_return = true
            stream = StringIO.new("")
        end
        # Creates the pipe for communicating with the block.
        rd,wr = IO.pipe
        # # Creates a process for executing the block.
        # pid = fork
        # if pid then
        #     # This is the parent: waits for the block execution result.
        #     # No need to write on the pipe. close it.
        #     wr.close
        #     # Read the result of the process and send it to stream
        #     until rd.eof?
        #         stream << rd.read
        #     end
        #     # No more need of rd.
        #     rd.close
        #     # Wait the end of the child process
        #     Process.wait(pid)
        #     # Where there a trouble?
        #     unless $?.exited? then
        #         # pid did not exit, internal error.
        #         raise "*Internal error*: safer process #{pid} did not exit."
        #     end
        #     if $?.exitstatus !=0 then
        #         # Reconstruct the exception from the stream, the exit
        #         # status is the number of line to use.
        #         e0 = Marshal.load( stream.string.each_line.
        #                            to_a[-$?.exitstatus..-1].join )
        #         # Then resend the eception encapsulated into another one
        #         # telling the safer process failed.
        #         begin
        #             raise e0
        #         rescue Exception => e1
        #             raise SaferException.new("*Error*: exception occured in safer process #{pid}.")
        #         end
        #     end
        # else
        #     # This is the child: enter in safe mode and execute the block.
        #     # No need to write on the pipe. close it.
        #     rd.close
        #     # Secure.
        #     secure
        #     # Execute the block.
        #     begin
        #         block.call(wr)
        #     rescue Exception => e
        #         # The exception is serialized and passed to the main process
        #         # through the pipe.
        #         e = Marshal.dump(e)
        #         wr << "\n" << e 
        #         # The exit status is the number of line of the serialized
        #         # exception.
        #         exit!(e.each_line.count)
        #     end
        #     # No more need of wr.
        #     wr.close
        #     # End the process without any error.
        #     exit!(0)
        # end
        # 
        # # Is there a string to return?
        # if to_return then
        #     return stream.string
        # else
        #     return nil
        # end

        # Secure.
        secure
        trouble = nil
        # Execute the block.
        begin
            block.call(wr)
        rescue Exception => e
            trouble = e
        end
        # No more need of wr.
        wr.close

        # Unsecure and process the result.
        unsecure
        # Read the result of the process and send it to stream
        until rd.eof?
            stream << rd.read
        end
        # No more need of rd.
        rd.close
        if trouble then
            begin
                raise trouble
            rescue Exception => e1
                raise SaferException.new("*Error*: exception occured in safe mode.")
            end
        end
          
        # Is there a string to return?
        if to_return then
            return stream.string
        else
            return nil
        end
    end
end
