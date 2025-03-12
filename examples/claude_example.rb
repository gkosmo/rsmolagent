require 'rsmolagent'
require 'anthropic'
require 'ostruct'

# Initialize the Anthropic client
client = Anthropic::Client.new(access_token: ENV["ANTHROPIC_API_KEY"])

# Create the LLM provider
llm = RSmolagent::ClaudeProvider.new(
  model_id: "claude-3-sonnet-20240229",  # Use a valid model ID
  client: client,
  temperature: 0.2,
  max_retries: 5,          # Add retry attempts for rate limiting
  initial_backoff: 2,      # Initial backoff time in seconds
  max_tokens: 4096         # Maximum tokens in response
)

# Create a calculator tool
class CalculatorTool < RSmolagent::Tool
  def initialize
    super(
      name: "calculator",
      description: "Perform mathematical calculations",
      input_schema: {
        expression: {
          type: "string",
          description: "The mathematical expression to evaluate (e.g., '2 + 2', '5 * 3')"
        }
      }
    )
  end

  def execute(args)
    expression = args[:expression]
    begin
      eval(expression).to_s
    rescue => e
      "Error: #{e.message}"
    end
  end
end

# Create an answer tool 
class AnswerTool < RSmolagent::Tool
  def initialize
    super(
      name: "answer",
      description: "Provide your final answer to the math problem",
      input_schema: {
        result: {
          type: "string",
          description: "The final numerical result of the calculation"
        },
        explanation: {
          type: "string",
          description: "Brief explanation of how you solved the problem (optional)"
        }
      }
    )
  end

  def execute(args)
    result = args[:result]
    explanation = args[:explanation]
    
    if explanation && !explanation.empty?
      "Final Answer: #{result} (#{explanation})"
    else
      "Final Answer: #{result}"
    end
  end
end

# Create the agent
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [CalculatorTool.new, AnswerTool.new],
  system_prompt: "You are a helpful assistant that can solve math problems. IMPORTANT: First use the calculator tool to perform the calculation, then use the answer tool to provide your final answer. Do not repeatedly use the calculator tool on the same expression.",
  max_steps: 3
)

# Run the agent
puts "Welcome to RSmolagent with Claude!"
puts "Ask a math question:"
question = gets.chomp

result = agent.run(question, verbose: true)
puts "\nFinal Answer: #{result}"