require "rsmolagent"
require "stringio"

# Helper method to capture stdout
def capture_stdout
  original_stdout = $stdout
  captured_stdout = StringIO.new
  $stdout = captured_stdout
  yield
  captured_stdout.string
ensure
  $stdout = original_stdout
end

# Mock OpenAI response for testing
class MockOpenAIResponse
  attr_reader :content, :tool_calls
  
  def initialize(content: nil, tool_calls: nil)
    @content = content
    @tool_calls = tool_calls
  end
end

# Mock OpenAI client for testing
class MockOpenAIClient
  attr_reader :requests, :responses
  
  def initialize(responses = [])
    @responses = responses.dup
    @requests = []
  end
  
  def chat(parameters:)
    @requests << parameters
    @responses.shift || MockOpenAIResponse.new(content: "I don't know how to respond.")
  end
end

# Mock OpenAI provider for testing
class MockLLMProvider
  attr_reader :calls, :responses
  
  def initialize(responses = [])
    @responses = responses.dup
    @calls = []
    @last_prompt_tokens = 0
    @last_completion_tokens = 0
  end
  
  def last_prompt_tokens
    @last_prompt_tokens
  end
  
  def last_completion_tokens
    @last_completion_tokens
  end
  
  def chat(messages, tools: nil, tool_choice: nil)
    @calls << {
      messages: messages,
      tools: tools,
      tool_choice: tool_choice
    }
    @responses.shift || MockOpenAIResponse.new(content: "I don't know how to respond.")
  end
  
  def extract_tool_calls(response)
    return [] unless response.tool_calls
    
    response.tool_calls.map do |tool_call|
      {
        name: tool_call[:name],
        arguments: tool_call[:arguments]
      }
    end
  end
end