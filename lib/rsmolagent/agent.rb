module RSmolagent
  class Agent
    attr_reader :memory, :tools, :llm, :max_steps
    
    def initialize(llm_provider:, tools: [], system_prompt: nil, max_steps: 10)
      @llm = llm_provider
      @memory = Memory.new
      @max_steps = max_steps
      @dynamic_tools = {}
      
      # Initialize system prompt
      default_system_prompt = "You are a helpful assistant that can use tools to solve tasks. " +
                              "When you need information or want to perform actions, use the provided tools. " +
                              "When you have the final answer, use the final_answer tool."
      
      system_message = system_prompt || default_system_prompt
      @memory.add_system_message(system_message)
      
      # Set up tools
      @tools = {}
      tools.each { |tool| @tools[tool.name] = tool }
      
      # Add final answer tool if not present
      unless @tools["final_answer"]
        final_answer_tool = FinalAnswerTool.new
        @tools[final_answer_tool.name] = final_answer_tool
      end
    end
    
    # Method to register a new tool during execution
    def register_tool(tool)
      @dynamic_tools[tool.name] = tool
      # Update memory with information about the new tool
      @memory.add_assistant_message("I've created a new tool called '#{tool.name}' that #{tool.description}")
    end
    
    def run(task, verbose: false)
      @memory.add_user_message(task)
      step_count = 0
      
      while step_count < @max_steps
        step_count += 1
        puts "Step #{step_count}/#{@max_steps}" if verbose
        
        # Get response from LLM
        response = execute_step
        
        # Check if we've reached a final answer
        if response[:final_answer]
          return response[:answer]
        end
        
        puts "Used tool: #{response[:tool_name]}" if verbose
      end
      
      # If we reach max steps without a final answer, return what we have
      "I couldn't complete the task in the allowed number of steps. My progress so far: " +
      @memory.history.map { |step| step[:type] == "tool_call" ? "#{step[:tool_name]}: #{step[:result]}" : "" }.join("\n")
    end
    
    private
    
    def execute_step
      # Get current messages
      messages = @memory.to_openai_messages
      
      # Combine static and dynamic tools
      all_tools = @tools.merge(@dynamic_tools)
      
      # Call LLM with all tools
      response = @llm.chat(messages, tools: all_tools.values)
      
      # Handle tool calls or final answer
      tool_calls = @llm.extract_tool_calls(response)
      
      if tool_calls.empty?
        # No tool calls, add as assistant message
        @memory.add_assistant_message(response.content)
        return { content: response.content }
      else
        # Process the first tool call
        tool_call = tool_calls.first
        tool_name = tool_call[:name]
        arguments = tool_call[:arguments]
        
        # Record assistant message with tool call
        @memory.add_assistant_message("I'll use the #{tool_name} tool.")
        
        if tool_name == "final_answer"
          # Handle final answer
          answer = arguments["answer"] || arguments[:answer] || ""
          @memory.add_final_answer(answer)
          return { final_answer: true, answer: answer }
        elsif tool_name == "answer"
          # Handle answer tool as final answer too
          result = arguments["result"] || arguments[:result] || ""
          explanation = arguments["explanation"] || arguments[:explanation] || ""
          
          final_answer = result
          if explanation && !explanation.empty?
            final_answer += " (#{explanation})"
          end
          
          @memory.add_final_answer(final_answer)
          return { final_answer: true, answer: final_answer }
        else
          # Execute the tool
          result = execute_tool(tool_name, arguments)
          
          # Check if this is a tool creation tool (like CustomClassExecutorTool)
          if tool_name == "create_tool" || tool_name == "custom_executor"
            # Try to create a new tool from the result
            begin
              # Parse the code from the result if needed
              code = extract_tool_code_from_result(result)
              
              if code
                # Try to create a tool from the code
                new_tool = Tools::CustomToolFactory.create_from_code(code)
                
                # Register the new tool
                register_tool(new_tool)
                
                # Add confirmation to the result
                result += "\n\nTool '#{new_tool.name}' has been created and is now available for use."
              end
            rescue => e
              result += "\n\nFailed to create tool: #{e.message}"
            end
          end
          
          # Add tool result to memory
          @memory.add_tool_message(tool_name, result)
          @memory.add_tool_call(tool_name, arguments, result)
          
          return { tool_name: tool_name, arguments: arguments, result: result }
        end
      end
    end
    
    def execute_tool(tool_name, arguments)
      # Look in both static and dynamic tools
      tool = @tools[tool_name] || @dynamic_tools[tool_name]
      
      if tool.nil?
        return "Error: Tool '#{tool_name}' not found"
      end
      
      begin
        tool.call(arguments)
      rescue => e
        "Error executing tool: #{e.message}"
      end
    end
    
    # Helper method to extract tool code from tool results
    def extract_tool_code_from_result(result)
      # Look for class definition in the result
      if result.include?("class") && result.include?("CustomToolBase")
        # For cleaner extraction, look for Ruby code blocks
        if result.include?("```ruby")
          # Extract code from markdown code blocks
          code_blocks = result.scan(/```ruby\n(.*?)\n```/m)
          return code_blocks.first.first if code_blocks.any?
        end
        
        # If no code blocks, try to extract class definition directly
        class_match = result.match(/class\s+\w+\s*<\s*CustomToolBase.*?end/m)
        return class_match[0] if class_match
      end
      
      # If we couldn't extract a class definition, return nil
      nil
    end
  end
end