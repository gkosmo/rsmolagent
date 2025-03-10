# RSmolagent

A lightweight Ruby library for creating AI agents that can use tools to solve tasks. Inspired by Python's smolagents library, RSmolagent provides a simple way to build agents that can interact with the world through tools.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rsmolagent'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rsmolagent
```

## Usage

RSmolagent is designed to be simple to use. Here's a basic example:

```ruby
require 'rsmolagent'
require 'ruby/openai'

# Create a custom tool
class CalculatorTool < RSmolagent::Tool
  def initialize
    super(
      name: "calculator",
      description: "Perform mathematical calculations",
      input_schema: {
        expression: {
          type: "string",
          description: "The mathematical expression to evaluate"
        }
      }
    )
  end

  def execute(args)
    expression = args[:expression]
    eval(expression).to_s
  rescue => e
    "Error: #{e.message}"
  end
end

# Initialize OpenAI client
client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

# Create LLM provider
llm = RSmolagent::OpenAIProvider.new(
  model_id: "gpt-3.5-turbo",
  client: client
)

# Create agent with tools
calculator = CalculatorTool.new
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [calculator]
)

# Run the agent
result = agent.run("What is 123 * 456?")
puts result  # Outputs the calculated result
```

## Features

- Simple interface for creating AI agents
- Support for custom tools
- Built-in memory for tracking conversation history
- Works with OpenAI API (easily extensible to other LLM providers)
- Automatic handling of tool calls and responses
- Built-in tools including web search
- Dynamic code execution and custom tool creation
- Ability to create tools from Ruby code at runtime

## Built-in Tools

RSmolagent comes with several built-in tools:

### WebSearchTool

Searches the web using DuckDuckGo's API:

```ruby
# Create a web search tool
web_search = RSmolagent::Tools::WebSearchTool.new(max_results: 3)

# Add it to your agent
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [web_search]
)

# The agent can now search the web
result = agent.run("What are the latest developments in AI?")
```

### Ruby Code Execution Tools

RSmolagent provides tools for executing Ruby code, allowing you to create custom tools dynamically:

#### 1. RubyExecutorTool

Executes arbitrary Ruby code in a controlled environment:

```ruby
# Create a Ruby executor tool
ruby_executor = RSmolagent::Tools::RubyExecutorTool.new

# Add it to your agent
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [ruby_executor]
)

# The agent can now execute Ruby code
result = agent.run("Calculate the factorial of 5")
```

#### 2. CustomClassExecutorTool

Creates and executes custom tool classes with defined structure:

```ruby
# Create a custom tool executor
custom_executor = RSmolagent::Tools::CustomClassExecutorTool.new

# Add it to your agent
agent = RSmolagent::Agent.new(
  llm_provider: llm,
  tools: [custom_executor]
)

# The agent can now create and use custom tools
result = agent.run("Create a tool to get the current date and then use it")
```

#### 3. Creating Custom Tools from Code

You can also create tools from code directly using the CustomToolFactory:

```ruby
# Define a custom tool class
tool_code = <<~RUBY
  class MyCustomTool < CustomToolBase
    def initialize
      super(
        "my_tool",
        "Description of what my tool does",
        {
          param1: {
            type: "string",
            description: "Parameter description"
          }
        }
      )
    end
    
    def run(args)
      # Implement tool logic here
      "Result: " + args[:param1].upcase
    end
  end
RUBY

# Create a tool from the code
my_tool = RSmolagent::Tools::CustomToolFactory.create_from_code(tool_code)

# Use the tool
my_tool.call(param1: "hello world")  # => "Result: HELLO WORLD"
```

## Creating Custom Tools

To create a custom tool, simply inherit from `RSmolagent::Tool` and implement the `execute` method:

```ruby
class MyTool < RSmolagent::Tool
  def initialize
    super(
      name: "my_tool",
      description: "Description of what the tool does",
      input_schema: {
        param1: {
          type: "string",
          description: "Description of parameter 1"
        },
        param2: {
          type: "number",
          description: "Description of parameter 2"
        }
      }
    )
  end

  def execute(args)
    # Implement your tool logic here
    # args will contain the parameters passed by the agent
    "Result of the tool execution"
  end
end
```

## Supporting Other LLM Providers

To add support for other LLM providers, inherit from `RSmolagent::LLMProvider` and implement the required methods:

```ruby
class MyLLMProvider < RSmolagent::LLMProvider
  def initialize(model_id:, **options)
    super(model_id: model_id, **options)
    # Initialize your LLM client
  end

  def chat(messages, tools: nil, tool_choice: nil)
    # Call your LLM provider's API
    # Return the response in a standardized format
  end

  def extract_tool_calls(response)
    # Extract tool calls from the response
    # Return an array of tool calls in the format:
    # [{ name: "tool_name", arguments: { param1: "value1", ... } }, ...]
  end
end
```

## Testing

RSmolagent includes a comprehensive test suite using RSpec. To run the tests:

```bash
# Install development dependencies
$ bundle install

# Run the tests
$ bundle exec rake spec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).