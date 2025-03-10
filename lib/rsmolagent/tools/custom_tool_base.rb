module RSmolagent
  module Tools
    # Base class that custom tools can inherit from when using the CustomClassExecutorTool
    class CustomToolBase
      attr_reader :name, :description, :input_schema
      
      def initialize(name, description, input_schema = {})
        @name = name
        @description = description
        @input_schema = input_schema
      end
      
      # This method must be implemented by subclasses
      def run(args = {})
        raise NotImplementedError, "Subclasses must implement the 'run' method"
      end
      
      # Helper methods that custom tools can use
      
      def fetch_url(url)
        require 'net/http'
        require 'uri'
        
        uri = URI(url)
        Net::HTTP.get(uri)
      end
      
      def parse_json(json_string)
        require 'json'
        JSON.parse(json_string)
      end
      
      def to_tool
        # Convert this custom tool to a RSmolagent::Tool
        RSmolagent::Tool.new(
          name: @name,
          description: @description,
          input_schema: @input_schema
        ) do |args|
          run(args)
        end
      end
      
      # Additional helper methods for safe file operations
      def read_file(path)
        # Only allow reading files from a specific directory in a real implementation
        File.read(path)
      end
      
      def write_file(path, content)
        # Only allow writing files to a specific directory in a real implementation
        File.write(path, content)
      end
    end
    
    # Factory for creating tools from custom tool classes
    class CustomToolFactory
      def self.create_from_code(code)
        # Create a clean binding
        context = Object.new.instance_eval { binding }
        
        # Make CustomToolBase available in the context
        context.eval("CustomToolBase = RSmolagent::Tools::CustomToolBase")
        
        # Evaluate the code to define the class
        context.eval(code)
        
        # Find the class name
        class_name = extract_class_name(code)
        
        # Create an instance of the class
        tool_instance = context.eval("#{class_name}.new")
        
        # Ensure it's a CustomToolBase
        unless tool_instance.is_a?(CustomToolBase)
          raise "The class must inherit from CustomToolBase"
        end
        
        # Convert to a Tool
        tool_instance.to_tool
      end
      
      private
      
      def self.extract_class_name(code)
        match = code.match(/class\s+([A-Z][A-Za-z0-9_]*)\s*(?:<\s*(?:CustomToolBase|[A-Z][A-Za-z0-9_]*))?\s*/)
        match ? match[1] : nil
      end
    end
  end
end