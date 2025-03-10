require "spec_helper"

RSpec.describe RSmolagent::LLMProvider do
  let(:provider) { RSmolagent::LLMProvider.new(model_id: "test-model") }
  
  describe "#initialize" do
    it "initializes with a model_id and options" do
      provider = RSmolagent::LLMProvider.new(
        model_id: "test-model",
        temperature: 0.7,
        custom_option: "value"
      )
      
      # We can't access private instance variables directly
      # but we can verify the provider was created successfully
      expect(provider).to be_a(RSmolagent::LLMProvider)
    end
  end
  
  describe "#chat" do
    it "raises NotImplementedError" do
      expect {
        provider.chat([{role: "user", content: "Hello"}])
      }.to raise_error(NotImplementedError)
    end
  end
  
  describe "#extract_tool_calls" do
    it "raises NotImplementedError" do
      expect {
        provider.extract_tool_calls(double)
      }.to raise_error(NotImplementedError)
    end
  end
  
  describe "#parse_json_if_needed" do
    it "parses JSON strings into objects" do
      result = provider.parse_json_if_needed('{"key":"value","number":42}')
      expect(result).to be_a(Hash)
      expect(result["key"]).to eq("value")
      expect(result["number"]).to eq(42)
    end
    
    it "returns non-JSON strings as-is" do
      result = provider.parse_json_if_needed("Not a JSON string")
      expect(result).to eq("Not a JSON string")
    end
    
    it "returns non-string values as-is" do
      result = provider.parse_json_if_needed(42)
      expect(result).to eq(42)
      
      obj = {a: 1}
      result = provider.parse_json_if_needed(obj)
      expect(result).to be(obj)
    end
  end
end

RSpec.describe RSmolagent::OpenAIProvider do
  let(:mock_client) { double("OpenAI::Client") }
  let(:provider) { RSmolagent::OpenAIProvider.new(model_id: "gpt-3.5-turbo", client: mock_client) }
  
  describe "#initialize" do
    it "initializes with model_id and client" do
      expect(provider).to be_a(RSmolagent::OpenAIProvider)
    end
  end
  
  describe "#chat" do
    let(:messages) { [{role: "user", content: "Hello"}] }
    let(:tools) { [RSmolagent::FinalAnswerTool.new] }
    let(:mock_response) do 
      double(
        "Response", 
        usage: double("Usage", prompt_tokens: 10, completion_tokens: 20),
        choices: [double("Choice", message: "I'm a response")]
      )
    end
    
    it "calls the OpenAI client with the correct parameters" do
      expect(mock_client).to receive(:chat).with(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: messages,
          temperature: 0.7
        }
      ).and_return(mock_response)
      
      provider.chat(messages)
      
      expect(provider.last_prompt_tokens).to eq(10)
      expect(provider.last_completion_tokens).to eq(20)
    end
    
    it "includes tools when provided" do
      expect(mock_client).to receive(:chat).with(
        parameters: hash_including(
          tools: kind_of(Array),
          tool_choice: "auto"
        )
      ).and_return(mock_response)
      
      provider.chat(messages, tools: tools)
    end
    
    it "allows overriding tool_choice" do
      expect(mock_client).to receive(:chat).with(
        parameters: hash_including(
          tool_choice: "required"
        )
      ).and_return(mock_response)
      
      provider.chat(messages, tools: tools, tool_choice: "required")
    end
  end
  
  describe "#extract_tool_calls" do
    it "extracts tool calls from response" do
      mock_tool_call = double(
        "ToolCall",
        function: double(
          "Function",
          name: "calculator",
          arguments: '{"expression":"2+2"}'
        )
      )
      
      mock_response = double(
        "Response",
        tool_calls: [mock_tool_call]
      )
      
      tool_calls = provider.extract_tool_calls(mock_response)
      
      expect(tool_calls.length).to eq(1)
      expect(tool_calls.first[:name]).to eq("calculator")
      expect(tool_calls.first[:arguments]).to eq({"expression" => "2+2"})
    end
    
    it "returns an empty array when no tool calls are present" do
      mock_response = double("Response", tool_calls: nil)
      
      tool_calls = provider.extract_tool_calls(mock_response)
      
      expect(tool_calls).to be_empty
    end
  end
end