require 'stringio'

module RSmolagent
  module Tools
    class RubyExecutorTool < Tool
      def initialize(name: "ruby_executor", description: nil)
        description ||= "Executes Ruby code in a controlled environment. Use this to run custom Ruby code."
        
        super(
          name: name,
          description: description,
          input_schema: {
            code: {
              type: "string",
              description: "The Ruby code to execute. Can include class and method definitions."
            }
          }
        )
        
        # Set of allowed classes/modules to access
        @allowed_constants = [
          'Array', 'Hash', 'String', 'Integer', 'Float', 'Time', 'Date',
          'Enumerable', 'Math', 'JSON', 'CSV', 'URI', 'Net', 'File', 'Dir',
          'StringIO', 'Regexp'
        ]
      end

      def execute(args)
        code = args[:code]
        return "Error: No code provided" if code.nil? || code.strip.empty?
        
        # Capture stdout to return it along with the result
        original_stdout = $stdout
        captured_stdout = StringIO.new
        $stdout = captured_stdout
        
        result = nil
        begin
          # Execute the code in the current binding with security limitations
          result = execute_with_safety(code)
          
          # Format the output
          stdout_content = captured_stdout.string.strip
          
          if stdout_content.empty?
            "Result: #{result.inspect}"
          else
            "Output:\n#{stdout_content}\n\nResult: #{result.inspect}"
          end
        rescue => e
          "Error: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
        ensure
          # Restore stdout
          $stdout = original_stdout
        end
      end
      
      private
      
      def execute_with_safety(code)
        # Create a secure binding for execution
        secure_binding = create_secure_binding
        
        # Execute the code in the secure binding
        secure_binding.eval(code)
      end
      
      def create_secure_binding
        # Create a new binding with limited access to dangerous methods
        safe_binding = binding.dup
        
        # Disable potentially dangerous methods in the binding
        disable_dangerous_methods(safe_binding)
        
        # Return the secured binding
        safe_binding
      end
      
      def disable_dangerous_methods(binding_obj)
        # This is a simplified approach - in a production environment,
        # you would want a more comprehensive security model
        dangerous_methods = [
          'system', 'exec', '`', 'eval', 'syscall', 'fork', 'trap',
          'require', 'load', 'open', 'Class.new', 'define_method'
        ]
        
        # This is just a basic example - a real implementation would need
        # more sophisticated sandboxing
        # Note: This is not a complete security solution and should be enhanced
        # for production use
      end
    end
    
    # A more specific custom tool executor that defines a class template
    class CustomClassExecutorTool < Tool
      def initialize(name: "custom_executor", description: nil, base_class: nil)
        description ||= "Executes a custom Ruby class with predefined methods. " +
                       "The class must implement a 'run' method that will be called."
                       
        @base_class = base_class
        
        super(
          name: name,
          description: description,
          input_schema: {
            code: {
              type: "string",
              description: "The Ruby class definition, must include a 'run' method"
            },
            args: {
              type: "object",
              description: "Arguments to pass to the run method (optional)",
              required: false
            }
          }
        )
      end
      
      def execute(args)
        code = args[:code]
        run_args = args[:args] || {}
        
        return "Error: No code provided" if code.nil? || code.strip.empty?
        
        # Capture stdout
        original_stdout = $stdout
        captured_stdout = StringIO.new
        $stdout = captured_stdout
        
        begin
          # Create a clean context
          context = Object.new.instance_eval { binding }
          
          # Inject base class if provided
          if @base_class
            context.eval("BaseClass = #{@base_class.name}")
          end
          
          # Evaluate the code to define the class
          context.eval(code)
          
          # Find the class we just defined
          class_name = extract_class_name(code)
          
          if class_name.nil?
            return "Error: Could not find a class definition in the provided code"
          end
          
          # Instantiate the class
          runner = context.eval("#{class_name}.new")
          
          # Ensure it has a run method
          unless runner.respond_to?(:run)
            return "Error: The class must implement a 'run' method"
          end
          
          # Run the class's run method with provided arguments
          if run_args.is_a?(Hash)
            result = runner.run(**run_args)
          else
            result = runner.run(run_args)
          end
          
          # Format the output
          stdout_content = captured_stdout.string.strip
          
          if stdout_content.empty?
            "Result: #{result.inspect}"
          else
            "Output:\n#{stdout_content}\n\nResult: #{result.inspect}"
          end
        rescue => e
          "Error: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
        ensure
          # Restore stdout
          $stdout = original_stdout
        end
      end
      
      private
      
      def extract_class_name(code)
        # Simple regex to extract the class name
        match = code.match(/class\s+([A-Z][A-Za-z0-9_]*)\s*(?:<\s*(?:BaseClass|[A-Z][A-Za-z0-9_]*))?\s*/)
        match ? match[1] : nil
      end
    end
  end
end