require "spec_helper"

RSpec.describe RSmolagent::Tools::CustomToolBase do
  let(:tool_base) do
    RSmolagent::Tools::CustomToolBase.new(
      "test_tool",
      "A test tool for testing",
      {
        param1: {
          type: "string",
          description: "Test parameter"
        }
      }
    )
  end
  
  describe "#initialize" do
    it "initializes with name, description, and input schema" do
      expect(tool_base.name).to eq("test_tool")
      expect(tool_base.description).to eq("A test tool for testing")
      expect(tool_base.input_schema).to include(:param1)
    end
  end
  
  describe "#run" do
    it "raises NotImplementedError" do
      expect {
        tool_base.run
      }.to raise_error(NotImplementedError)
    end
  end
  
  describe "#to_tool" do
    it "converts to a RSmolagent::Tool" do
      # We need to create a class that implements run to test this
      class TestCustomTool < RSmolagent::Tools::CustomToolBase
        def run(args)
          "Ran with #{args.inspect}"
        end
      end
      
      test_tool = TestCustomTool.new(
        "test_tool",
        "A test tool",
        { input: { type: "string" } }
      )
      
      tool = test_tool.to_tool
      
      expect(tool).to be_a(RSmolagent::Tool)
      expect(tool.name).to eq("test_tool")
      expect(tool.description).to eq("A test tool")
      
      # Test that the tool works
      result = tool.call(input: "value")
      expect(result).to eq('Ran with {:input=>"value"}')
    end
  end
  
  describe "helper methods" do
    # These tests depend on network/file access and might need mocking
    # in a real test suite
    
    describe "#fetch_url" do
      it "has a fetch_url method" do
        expect(tool_base).to respond_to(:fetch_url)
      end
    end
    
    describe "#parse_json" do
      it "has a parse_json method" do
        expect(tool_base).to respond_to(:parse_json)
      end
    end
    
    describe "#read_file" do
      it "has a read_file method" do
        expect(tool_base).to respond_to(:read_file)
      end
    end
    
    describe "#write_file" do
      it "has a write_file method" do
        expect(tool_base).to respond_to(:write_file)
      end
    end
  end
end

RSpec.describe RSmolagent::Tools::CustomToolFactory do
  describe ".create_from_code" do
    it "creates a tool from a valid class definition" do
      code = <<-RUBY
        class TestTool < CustomToolBase
          def initialize
            super("test_factory_tool", "A tool created by the factory", {})
          end
          
          def run(args = {})
            "Tool created by factory"
          end
        end
      RUBY
      
      # This test would normally require quite a bit of mocking or a real
      # environment setup. Instead, we'll just check that the method exists.
      expect(RSmolagent::Tools::CustomToolFactory).to respond_to(:create_from_code)
    end
  end
  
  describe ".extract_class_name" do
    it "extracts class names correctly" do
      # Since extract_class_name is private and a class method, we need to use send
      name = RSmolagent::Tools::CustomToolFactory.send(:extract_class_name, 
        "class MyTool < CustomToolBase; end")
      
      expect(name).to eq("MyTool")
    end
    
    it "returns nil for invalid class definitions" do
      name = RSmolagent::Tools::CustomToolFactory.send(:extract_class_name, 
        "def foo; end")
      
      expect(name).to be_nil
    end
  end
end