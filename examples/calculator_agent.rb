require 'rsmolagent'
require 'ruby/openai'

# Create a simple calculator tool
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

# Create a weather tool
class WeatherTool < RSmolagent::Tool
  def initialize
    super(
      name: "weather",
      description: "Get the current weather for a location",
      input_schema: {
        location: {
          type: "string",
          description: "The city or location to get weather for"
        }
      }
    )
  end

  def execute(args)
    location = args[:location]
    # In a real implementation, this would call a weather API
    # For demonstration, just return mock data
    temperatures = {
      "new york" => "72°F, Partly Cloudy",
      "san francisco" => "65°F, Foggy",
      "miami" => "85°F, Sunny",
      "chicago" => "60°F, Windy"
    }
    
    location_key = location.downcase
    if temperatures.key?(location_key)
      "Current weather in #{location}: #{temperatures[location_key]}"
    else
      "Weather data not available for #{location}"
    end
  end
end

# Initialize the OpenAI client
# In a real application, you would use your own API key
client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

# Create the LLM provider
llm = RSmolagent::OpenAIProvider.new(
  model_id: "gpt-3.5-turbo",
  client: client,
  temperature: 0.2
)

# Create tools
calculator = CalculatorTool.new
weather = WeatherTool.new

# Create the agent
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [calculator, weather],
  max_steps: 5
)

# Run the agent
puts "Welcome to RSmolagent Calculator & Weather Assistant!"
puts "Ask a question about math or weather:"
question = gets.chomp

result = agent.run(question, verbose: true)
puts "\nFinal Answer: #{result}"