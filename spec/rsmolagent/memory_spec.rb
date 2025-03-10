require "spec_helper"

RSpec.describe RSmolagent::Memory do
  let(:memory) { RSmolagent::Memory.new }
  
  describe "#initialize" do
    it "initializes with empty messages and history" do
      expect(memory.messages).to be_empty
      expect(memory.history).to be_empty
    end
  end
  
  describe "#add_system_message" do
    it "adds a system message to messages" do
      memory.add_system_message("System instruction")
      
      expect(memory.messages.length).to eq(1)
      expect(memory.messages.first[:role]).to eq("system")
      expect(memory.messages.first[:content]).to eq("System instruction")
    end
  end
  
  describe "#add_user_message" do
    it "adds a user message to messages" do
      memory.add_user_message("User query")
      
      expect(memory.messages.length).to eq(1)
      expect(memory.messages.first[:role]).to eq("user")
      expect(memory.messages.first[:content]).to eq("User query")
    end
  end
  
  describe "#add_assistant_message" do
    it "adds an assistant message to messages" do
      memory.add_assistant_message("Assistant response")
      
      expect(memory.messages.length).to eq(1)
      expect(memory.messages.first[:role]).to eq("assistant")
      expect(memory.messages.first[:content]).to eq("Assistant response")
    end
  end
  
  describe "#add_tool_message" do
    it "adds a tool message to messages" do
      memory.add_tool_message("calculator", "42")
      
      expect(memory.messages.length).to eq(1)
      expect(memory.messages.first[:role]).to eq("tool")
      expect(memory.messages.first[:name]).to eq("calculator")
      expect(memory.messages.first[:content]).to eq("42")
    end
  end
  
  describe "#add_tool_call" do
    it "adds a tool call to history" do
      step = memory.add_tool_call("calculator", {expression: "2+2"}, "4")
      
      expect(memory.history.length).to eq(1)
      expect(memory.history.first).to eq(step)
      expect(step[:type]).to eq("tool_call")
      expect(step[:tool_name]).to eq("calculator")
      expect(step[:arguments]).to eq({expression: "2+2"})
      expect(step[:result]).to eq("4")
      expect(step[:timestamp]).to be_a(Time)
    end
  end
  
  describe "#add_final_answer" do
    it "adds a final answer to history" do
      step = memory.add_final_answer("The answer is 42")
      
      expect(memory.history.length).to eq(1)
      expect(memory.history.first).to eq(step)
      expect(step[:type]).to eq("final_answer")
      expect(step[:answer]).to eq("The answer is 42")
      expect(step[:timestamp]).to be_a(Time)
    end
  end
  
  describe "#to_openai_messages" do
    before do
      memory.add_system_message("System instruction")
      memory.add_user_message("User query")
      memory.add_assistant_message("Assistant response")
      memory.add_tool_message("calculator", "42")
    end
    
    it "formats messages for OpenAI API" do
      formatted = memory.to_openai_messages
      
      expect(formatted.length).to eq(4)
      
      expect(formatted[0][:role]).to eq("system")
      expect(formatted[0][:content]).to eq("System instruction")
      
      expect(formatted[1][:role]).to eq("user")
      expect(formatted[1][:content]).to eq("User query")
      
      expect(formatted[2][:role]).to eq("assistant")
      expect(formatted[2][:content]).to eq("Assistant response")
      
      expect(formatted[3][:role]).to eq("tool")
      expect(formatted[3][:tool_call_id]).to eq("call_calculator")
      expect(formatted[3][:content]).to eq("42")
    end
  end
end