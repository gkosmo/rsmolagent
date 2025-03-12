module RSmolagent
  class LLMProvider
    attr_reader :last_prompt_tokens, :last_completion_tokens

    def initialize(model_id:, **options)
      @model_id = model_id
      @options = options
      @last_prompt_tokens = 0
      @last_completion_tokens = 0
    end

    def chat(messages, tools: nil, tool_choice: nil)
      raise NotImplementedError, "Subclasses must implement the 'chat' method"
    end

    def extract_tool_calls(response)
      raise NotImplementedError, "Subclasses must implement the 'extract_tool_calls' method"
    end

    def parse_json_if_needed(text)
      return text unless text.is_a?(String)
      
      begin
        JSON.parse(text)
      rescue JSON::ParserError
        text
      end
    end
  end

  class OpenAIProvider < LLMProvider
    def initialize(model_id:, client:, **options)
      super(model_id: model_id, **options)
      @client = client
      @max_retries = options[:max_retries] || 3
      @initial_backoff = options[:initial_backoff] || 1
    end

    def chat(messages, tools: nil, tool_choice: nil)
      params = {
        model: @model_id,
        messages: messages,
        temperature: @options[:temperature] || 0.7,
      }

      # Add tools if provided
      if tools && !tools.empty?
        params[:tools] = tools.map(&:to_json_schema)
        params[:tool_choice] = tool_choice || "auto"
      end

      retries = 0
      begin
        response = @client.chat(parameters: params)
        
        # Update token counts
        @last_prompt_tokens = response.usage.prompt_tokens
        @last_completion_tokens = response.usage.completion_tokens
        
        response.choices.first.message
      rescue Faraday::TooManyRequestsError => e
        retries += 1
        if retries <= @max_retries
          # Exponential backoff with jitter
          sleep_time = @initial_backoff * (2 ** (retries - 1)) * (0.5 + rand)
          puts "Rate limited (429). Retrying in #{sleep_time.round(1)} seconds... (#{retries}/#{@max_retries})"
          sleep(sleep_time)
          retry
        else
          puts "Max retries (#{@max_retries}) exceeded. Rate limit error persists."
          raise e
        end
      end
    end

    def extract_tool_calls(response)
      return [] unless response.tool_calls
      
      response.tool_calls.map do |tool_call|
        {
          name: tool_call.function.name,
          arguments: parse_json_if_needed(tool_call.function.arguments)
        }
      end
    end
  end

  class ClaudeProvider < LLMProvider
    def initialize(model_id:, client:, **options)
      super(model_id: model_id, **options)
      @client = client
      @max_retries = options[:max_retries] || 3
      @initial_backoff = options[:initial_backoff] || 1
    end

    def chat(messages, tools: nil, tool_choice: nil)
      # Prepare the system message
      system_message = nil
      filtered_messages = messages.reject do |message|
        if message[:role] == 'system'
          system_message = message[:content]
          true
        else
          false
        end
      end

      # Convert messages format for Claude
      claude_messages = filtered_messages.map do |msg|
        role = msg[:role] == 'assistant' ? 'assistant' : 'user'
        
        # Process assistant messages to help guide Claude's behavior
        content = msg[:content]
        if role == 'assistant' && content.start_with?("I'll use the calculator tool")
          content = "I'll use the calculator tool to solve this problem."
        end
        
        { role: role, content: content }
      end

      # Check current state of conversation to guide the model
      calculator_used = false
      calculator_result = nil
      
      # Analyze the conversation to detect patterns
      claude_messages.each_with_index do |msg, i|
        # Check for calculator result
        if msg[:role] == 'user' && msg[:content].match?(/^\d+$/) && i > 0
          calculator_used = true
          calculator_result = msg[:content]
        end
      end
      
      # Prepare parameters
      params = {
        model: @model_id,
        messages: claude_messages,
        temperature: @options[:temperature] || 0.7,
        max_tokens: @options[:max_tokens] || 4096
      }

      # Add system message with appropriate guidance based on conversation state
      if system_message
        enhanced_system = system_message.dup
        if calculator_used && calculator_result
          enhanced_system += " IMPORTANT: You have already calculated the result (#{calculator_result}). Use the answer tool now to provide your final answer."
        end
        params[:system] = enhanced_system
      end

      # Add tools if provided - Format specifically for Claude's API
      if tools && !tools.empty?
        claude_tools = tools.map do |tool|
          schema = tool.to_json_schema
          {
            name: schema["name"],
            description: schema["description"],
            input_schema: {
              type: "object",
              properties: schema["parameters"]["properties"],
              required: schema["parameters"]["required"]
            }
          }
        end
        params[:tools] = claude_tools
      end

      # Debug information
      puts "CLAUDE REQUEST PARAMS:"
      puts "Model: #{params[:model]}"
      puts "Messages: #{params[:messages].inspect}"
      puts "System: #{params[:system]}" if params[:system]
      puts "Tools: #{params[:tools].inspect}" if params[:tools]
      
      retries = 0
      begin
        response = @client.messages(parameters: params)
        
        # Update token counts if available
        if response.respond_to?(:usage)
          @last_prompt_tokens = response.usage.input_tokens if response.usage.respond_to?(:input_tokens)
          @last_completion_tokens = response.usage.output_tokens if response.usage.respond_to?(:output_tokens)
        end
        
        # Create a response object that matches the structure expected by Agent
        content = nil
        
        # Handle hash response
        if response.is_a?(Hash) && response["content"].is_a?(Array)
          text_item = response["content"].find { |item| item["type"] == "text" }
          content = text_item["text"] if text_item
        # Handle object response
        elsif response.respond_to?(:content) && response.content.is_a?(Array) && !response.content.empty?
          content_item = response.content.find { |item| item.type == 'text' }
          content = content_item ? content_item.text : nil
        end

        OpenStruct.new(
          content: content,
          tool_calls: extract_tool_calls_from_response(response)
        )
      rescue => e
        if e.is_a?(Faraday::TooManyRequestsError) || e.message.include?('429')
          retries += 1
          if retries <= @max_retries
            # Exponential backoff with jitter
            sleep_time = @initial_backoff * (2 ** (retries - 1)) * (0.5 + rand)
            puts "Rate limited (429). Retrying in #{sleep_time.round(1)} seconds... (#{retries}/#{@max_retries})"
            sleep(sleep_time)
            retry
          else
            puts "Max retries (#{@max_retries}) exceeded. Rate limit error persists."
            raise e
          end
        elsif e.is_a?(Faraday::BadRequestError) || e.message.include?('400')
          puts "Bad request error (400). Request parameters may be invalid:"
          puts "Error details: #{e.message}"
          puts "Response body: #{e.response[:body] if e.respond_to?(:response) && e.response.is_a?(Hash)}"
          raise e
        else
          puts "Unknown error occurred: #{e.class} - #{e.message}"
          raise e
        end
      end
    end

    def extract_tool_calls_from_response(response)
      # Debug information about the response
      puts "Response type: #{response.class}"
      puts "Response content: #{response.inspect}"
      
      # Check if response is a hash (the anthropic gem might return raw hash)
      if response.is_a?(Hash)
        puts "Response is a Hash, extracting from hash"
        content_array = response["content"] rescue nil
        return nil unless content_array && content_array.is_a?(Array)
        
        tool_calls_content = content_array.find { |c| c["type"] == "tool_use" }
        return nil unless tool_calls_content
        
        tool_call = tool_calls_content["id"] ? {
          "name" => tool_calls_content["name"],
          "input" => tool_calls_content["input"]
        } : nil
        
        return nil unless tool_call
        
        return [
          OpenStruct.new(
            function: OpenStruct.new(
              name: tool_call["name"],
              arguments: tool_call["input"].to_json
            )
          )
        ]
      end
      
      # Handle object-style response (if anthropic gem parses to objects)
      begin
        return nil unless response.respond_to?(:content) && 
                          response.content.is_a?(Array) && 
                          !response.content.empty?
                          
        tool_use_blocks = response.content.select { |c| c.type == "tool_use" }
        return nil if tool_use_blocks.empty?
        
        return tool_use_blocks.map do |tool_block|
          OpenStruct.new(
            function: OpenStruct.new(
              name: tool_block.name,
              arguments: tool_block.input.to_json
            )
          )
        end
      rescue => e
        puts "Error extracting tool calls: #{e.message}"
        nil
      end
    end

    def extract_tool_calls(response)
      return [] unless response.tool_calls
      
      response.tool_calls.map do |tool_call|
        {
          name: tool_call.function.name,
          arguments: parse_json_if_needed(tool_call.function.arguments)
        }
      end
    end
  end
end