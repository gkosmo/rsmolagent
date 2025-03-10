require 'rsmolagent'
require 'ruby/openai'

# Initialize the OpenAI client
client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

# Create the LLM provider
llm = RSmolagent::OpenAIProvider.new(
  model_id: "gpt-3.5-turbo",
  client: client,
  temperature: 0.2
)

# Create a web search tool
web_search = RSmolagent::Tools::WebSearchTool.new(max_results: 3)

# Create the agent
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [web_search],
  system_prompt: "You are a helpful research assistant. Use the web_search tool to find information about topics, then provide comprehensive answers based on the search results.",
  max_steps: 5
)

# Run the agent
puts "Welcome to RSmolagent Research Assistant!"
puts "What would you like to research today?"
question = gets.chomp

result = agent.run(question, verbose: true)
puts "\nFinal Answer: #{result}"