require "spec_helper"

RSpec.describe RSmolagent::Tool do
  describe "#initialize" do
    it "initializes with name, description, and input schema" do
      tool = RSmolagent::Tool.new(
        name: "test_tool",
        description: "A test tool",
        input_schema: {
          input1: {
            type: "string",
            description: "An input parameter"
          }
        }
      )
      
      expect(tool.name).to eq("test_tool")
      expect(tool.description).to eq("A test tool")
      expect(tool.input_schema).to include(:input1)
    end
  end
  
  describe "#call" do
    context "with a block-defined tool" do
      it "executes the block with the given arguments" do
        tool = RSmolagent::Tool.new(
          name: "add",
          description: "Adds two numbers",
          input_schema: {
            a: { type: "number" },
            b: { type: "number" }
          }
        ) do |args|
          args[:a] + args[:b]
        end
        
        result = tool.call(a: 2, b: 3)
        expect(result).to eq(5)
      end
    end
    
    context "with a subclassed tool" do
      class TestTool < RSmolagent::Tool
        def execute(args)
          "Executed with #{args.inspect}"
        end
      end
      
      it "calls the execute method with the given arguments" do
        tool = TestTool.new(
          name: "test",
          description: "A test tool"
        )
        
        result = tool.call(param: "value")
        expect(result).to eq('Executed with {:param=>"value"}')
      end
    end
  end
  
  describe "#to_json_schema" do
    it "returns a properly formatted JSON schema" do
      tool = RSmolagent::Tool.new(
        name: "test_tool",
        description: "A test tool",
        input_schema: {
          required_param: {
            type: "string",
            description: "A required parameter"
          },
          optional_param: {
            type: "number",
            description: "An optional parameter",
            required: false
          }
        }
      )
      
      schema = tool.to_json_schema
      
      expect(schema["name"]).to eq("test_tool")
      expect(schema["description"]).to eq("A test tool")
      expect(schema["parameters"]["type"]).to eq("object")
      expect(schema["parameters"]["properties"]).to include("required_param", "optional_param")
      expect(schema["parameters"]["required"]).to include("required_param")
      expect(schema["parameters"]["required"]).not_to include("optional_param")
    end
  end
end

RSpec.describe RSmolagent::FinalAnswerTool do
  let(:tool) { RSmolagent::FinalAnswerTool.new }
  
  it "has the correct name and description" do
    expect(tool.name).to eq("final_answer")
    expect(tool.description).to match(/final answer/)
  end
  
  it "returns the provided answer as a string" do
    result = tool.call(answer: "This is the answer")
    expect(result).to eq("This is the answer")
    
    result = tool.call(answer: 42)
    expect(result).to eq("42")
  end
end