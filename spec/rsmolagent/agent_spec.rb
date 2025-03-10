require "spec_helper"

RSpec.describe RSmolagent::Agent do
  let(:mock_llm) { MockLLMProvider.new }
  let(:calculator_tool) do
    RSmolagent::Tool.new(
      name: "calculator",
      description: "Performs calculations",
      input_schema: {
        expression: {
          type: "string",
          description: "Mathematical expression to evaluate"
        }
      }
    ) do |args|
      eval(args[:expression]).to_s
    end
  end
  
  let(:agent) { RSmolagent::Agent.new(llm_provider: mock_llm, tools: [calculator_tool]) }
  
  describe "#initialize" do
    it "initializes with required parameters" do
      agent = RSmolagent::Agent.new(llm_provider: mock_llm)
      
      expect(agent.llm).to eq(mock_llm)
      expect(agent.tools.keys).to include("final_answer")
      expect(agent.max_steps).to eq(10)
    end
    
    it "adds provided tools" do
      agent = RSmolagent::Agent.new(
        llm_provider: mock_llm,
        tools: [calculator_tool]
      )
      
      expect(agent.tools.keys).to include("calculator", "final_answer")
    end
    
    it "adds a system prompt to memory" do
      agent = RSmolagent::Agent.new(
        llm_provider: mock_llm,
        system_prompt: "Custom prompt"
      )
      
      expect(agent.memory.messages.first[:role]).to eq("system")
      expect(agent.memory.messages.first[:content]).to eq("Custom prompt")
    end
    
    it "allows setting custom max_steps" do
      agent = RSmolagent::Agent.new(
        llm_provider: mock_llm,
        max_steps: 5
      )
      
      expect(agent.max_steps).to eq(5)
    end
  end
  
  describe "#register_tool" do
    it "registers a new tool during execution" do
      new_tool = RSmolagent::Tool.new(
        name: "new_tool",
        description: "A new tool"
      ) { "Tool result" }
      
      agent.register_tool(new_tool)
      
      # Can't access @dynamic_tools directly, but we can check the message was added
      expect(agent.memory.messages.last[:role]).to eq("assistant")
      expect(agent.memory.messages.last[:content]).to include("new_tool")
    end
  end
  
  describe "#run" do
    context "with a final answer" do
      it "returns the final answer" do
        # Mock response with final answer tool call
        mock_llm.responses << MockOpenAIResponse.new(
          tool_calls: [
            {
              name: "final_answer",
              arguments: { answer: "The final answer is 42" }
            }
          ]
        )
        
        result = agent.run("What is the meaning of life?")
        
        expect(result).to eq("The final answer is 42")
      end
    end
    
    context "with tool calls" do
      it "executes tools and continues until final answer" do
        # First response: call calculator
        mock_llm.responses << MockOpenAIResponse.new(
          tool_calls: [
            {
              name: "calculator",
              arguments: { expression: "2 + 2" }
            }
          ]
        )
        
        # Second response: final answer
        mock_llm.responses << MockOpenAIResponse.new(
          tool_calls: [
            {
              name: "final_answer",
              arguments: { answer: "The answer is 4" }
            }
          ]
        )
        
        result = agent.run("What is 2 + 2?")
        
        expect(result).to eq("The answer is 4")
        expect(mock_llm.calls.size).to eq(2)
        
        # Verify first call includes tool definition
        expect(mock_llm.calls.first[:tools]).to include(
          have_attributes(name: "calculator"),
          have_attributes(name: "final_answer")
        )
      end
    end
    
    context "with max steps reached" do
      it "returns a message about reaching max steps" do
        # Setup multiple tool calls without final answer
        5.times do
          mock_llm.responses << MockOpenAIResponse.new(
            tool_calls: [
              {
                name: "calculator",
                arguments: { expression: "2 + 2" }
              }
            ]
          )
        end
        
        agent = RSmolagent::Agent.new(
          llm_provider: mock_llm,
          tools: [calculator_tool],
          max_steps: 3
        )
        
        result = agent.run("What is 2 + 2?")
        
        expect(result).to include("couldn't complete the task")
        expect(mock_llm.calls.size).to eq(3) # Should stop at max_steps
      end
    end
    
    context "with verbose output" do
      it "prints step information to stdout" do
        mock_llm.responses << MockOpenAIResponse.new(
          tool_calls: [
            {
              name: "calculator",
              arguments: { expression: "2 + 2" }
            }
          ]
        )
        
        mock_llm.responses << MockOpenAIResponse.new(
          tool_calls: [
            {
              name: "final_answer",
              arguments: { answer: "The answer is 4" }
            }
          ]
        )
        
        output = capture_stdout do
          agent.run("What is 2 + 2?", verbose: true)
        end
        
        expect(output).to include("Step 1")
        expect(output).to include("Used tool: calculator")
      end
    end
  end
  
  describe "dynamic tool creation" do
    it "extracts and registers tools from custom executor results" do
      # Create a custom executor tool
      custom_executor = RSmolagent::Tool.new(
        name: "create_tool",
        description: "Creates a custom tool"
      ) do |args|
        # Return a mock tool definition
        <<-TOOL
```ruby
class WeatherTool < CustomToolBase
  def initialize
    super(
      "weather",
      "Gets weather information",
      {
        location: {
          type: "string",
          description: "Location to get weather for"
        }
      }
    )
  end
  
  def run(args)
    "Weather for #{args[:location]}: Sunny, 72°F"
  end
end
```
TOOL
      end
      
      # Add the mocks and stubs to simulate tool creation
      # This test requires a real CustomToolBase class and CustomToolFactory to be available
      # or extensive mocking of these components
      
      # For now, we'll just verify that the agent handles the basic scenario correctly
      # A more thorough test would involve a full integration test
      
      tool_registry = {}
      
      agent = RSmolagent::Agent.new(
        llm_provider: mock_llm,
        tools: [custom_executor]
      )
      
      # Mock the extract_tool_code_from_result method to return a known piece of code
      allow(agent).to receive(:extract_tool_code_from_result) do |result|
        if result.include?("WeatherTool")
          "class WeatherTool < CustomToolBase; end"
        else
          nil
        end
      end
      
      # Mock the CustomToolFactory.create_from_code method
      weather_tool = double("WeatherTool", 
                             name: "weather", 
                             description: "Gets weather information")
      
      allow(RSmolagent::Tools::CustomToolFactory).to receive(:create_from_code) do |code|
        weather_tool
      end
      
      # Mock calls to register_tool
      allow(agent).to receive(:register_tool) do |tool|
        tool_registry[tool.name] = tool
      end
      
      # Set up the mock responses
      mock_llm.responses << MockOpenAIResponse.new(
        tool_calls: [
          {
            name: "create_tool",
            arguments: { code: "weather_tool_code" }
          }
        ]
      )
      
      mock_llm.responses << MockOpenAIResponse.new(
        tool_calls: [
          {
            name: "final_answer",
            arguments: { answer: "Created a weather tool" }
          }
        ]
      )
      
      result = agent.run("Create a weather tool")
      
      # Verify that register_tool was called with the weather tool
      expect(agent).to have_received(:register_tool).with(weather_tool)
    end
  end
end