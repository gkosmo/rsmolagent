require 'rsmolagent'
require 'ruby/openai'

# Initialize the OpenAI client
client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

# Create the LLM provider
llm = RSmolagent::OpenAIProvider.new(
  model_id: "gpt-4", # Using GPT-4 for better code generation
  client: client,
  temperature: 0.2
)

# Create a custom class executor tool
custom_executor = RSmolagent::Tools::CustomClassExecutorTool.new(
  name: "create_tool",
  description: "Creates a custom tool that can be used to solve tasks. The code should define a class that inherits from CustomToolBase and implements a run method."
)

# Create the agent with only the custom executor tool
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [custom_executor],
  system_prompt: "You are an AI assistant that specializes in creating custom tools on-the-fly to solve tasks. " +
                "You can create tools using the 'create_tool' command and then use those tools to solve problems. " +
                "When creating a tool, define a class that inherits from CustomToolBase with a run method that takes args as a parameter. " +
                "Make sure each tool does one specific thing well.",
  max_steps: 15
)

puts "This agent can create and use tools dynamically."
puts "Give it a complex task that might require multiple tools:"
task = gets.chomp

puts "\nExecuting with verbose output...\n"
result = agent.run(task, verbose: true)

puts "\nFinal Answer: #{result}