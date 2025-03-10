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

      response = @client.chat(parameters: params)
      
      # Update token counts
      @last_prompt_tokens = response.usage.prompt_tokens
      @last_completion_tokens = response.usage.completion_tokens
      
      response.choices.first.message
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