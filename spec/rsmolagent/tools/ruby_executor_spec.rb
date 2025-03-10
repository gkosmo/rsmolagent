require "spec_helper"

RSpec.describe RSmolagent::Tools::RubyExecutorTool do
  let(:tool) { RSmolagent::Tools::RubyExecutorTool.new }
  
  describe "#initialize" do
    it "initializes with default parameters" do
      expect(tool.name).to eq("ruby_executor")
      expect(tool.description).to include("Ruby code")
      expect(tool.input_schema).to include(:code)
    end
    
    it "allows custom name and description" do
      custom_tool = RSmolagent::Tools::RubyExecutorTool.new(
        name: "custom_ruby",
        description: "Custom description"
      )
      
      expect(custom_tool.name).to eq("custom_ruby")
      expect(custom_tool.description).to eq("Custom description")
    end
  end
  
  describe "#execute" do
    it "executes simple Ruby code" do
      result = tool.call(code: "1 + 1")
      
      expect(result).to include("Result: 2")
    end
    
    it "captures and returns stdout output" do
      result = tool.call(code: "puts 'Hello, world!'")
      
      expect(result).to include("Output:")
      expect(result).to include("Hello, world!")
    end
    
    it "handles errors in the code" do
      result = tool.call(code: "1 / 0")
      
      expect(result).to include("Error:")
      expect(result).to include("divided by 0")
    end
    
    it "returns an error for empty code" do
      result = tool.call(code: "")
      
      expect(result).to include("Error: No code provided")
    end
    
    # Security tests would be good to add here, but they're complex and depend
    # on the specific security implementation
  end
end

RSpec.describe RSmolagent::Tools::CustomClassExecutorTool do
  let(:tool) { RSmolagent::Tools::CustomClassExecutorTool.new }
  
  describe "#initialize" do
    it "initializes with default parameters" do
      expect(tool.name).to eq("custom_executor")
      expect(tool.description).to include("custom Ruby class")
      expect(tool.input_schema).to include(:code)
      expect(tool.input_schema).to include(:args)
    end
    
    it "allows custom name and description" do
      custom_tool = RSmolagent::Tools::CustomClassExecutorTool.new(
        name: "class_exec",
        description: "Custom description"
      )
      
      expect(custom_tool.name).to eq("class_exec")
      expect(custom_tool.description).to eq("Custom description")
    end
    
    it "accepts a base_class parameter" do
      base_class = Class.new
      custom_tool = RSmolagent::Tools::CustomClassExecutorTool.new(
        base_class: base_class
      )
      
      expect(custom_tool).to be_a(RSmolagent::Tools::CustomClassExecutorTool)
    end
  end
  
  describe "#execute" do
    it "returns an error for empty code" do
      result = tool.call(code: "")
      
      expect(result).to include("Error: No code provided")
    end
    
    it "returns an error if no class definition is found" do
      result = tool.call(code: "def foo; end")
      
      expect(result).to include("Error: Could not find a class definition")
    end
    
    it "returns an error if class doesn't have a run method" do
      result = tool.call(code: "class TestClass; end")
      
      expect(result).to include("Error: The class must implement a 'run' method")
    end
    
    # For more complex tests that would actually execute valid classes,
    # we would need to either mock certain behaviors or set up a proper
    # testing environment with CustomToolBase available
  end
  
  describe "#extract_class_name" do
    it "extracts simple class names correctly" do
      # Since extract_class_name is private, we need to use send to call it
      name = tool.send(:extract_class_name, "class MyClass; end")
      
      expect(name).to eq("MyClass")
    end
    
    it "extracts class names with inheritance correctly" do
      name = tool.send(:extract_class_name, "class MyClass < BaseClass; end")
      
      expect(name).to eq("MyClass")
    end
    
    it "extracts class names with whitespace correctly" do
      name = tool.send(:extract_class_name, "class  MyClass  <  BaseClass ; end")
      
      expect(name).to eq("MyClass")
    end
    
    it "returns nil for invalid class definitions" do
      name = tool.send(:extract_class_name, "def foo; end")
      
      expect(name).to be_nil
    end
  end
end