module RSmolagent
  class Memory
    attr_reader :messages, :history

    def initialize
      @messages = []
      @history = []
    end

    def add_system_message(content)
      add_message("system", content)
    end

    def add_user_message(content)
      add_message("user", content)
    end

    def add_assistant_message(content)
      add_message("assistant", content)
    end

    def add_tool_message(name, content)
      @messages << { role: "tool", name: name, content: content }
    end

    def add_tool_call(tool_name, arguments, result)
      step = {
        type: "tool_call",
        tool_name: tool_name,
        arguments: arguments,
        result: result,
        timestamp: Time.now
      }
      @history << step
      step
    end

    def add_final_answer(answer)
      step = {
        type: "final_answer",
        answer: answer,
        timestamp: Time.now
      }
      @history << step
      step
    end

    def to_openai_messages
      @messages.map do |msg|
        if msg[:role] == "tool"
          { role: "tool", tool_call_id: "call_#{msg[:name]}", content: msg[:content].to_s }
        else
          { role: msg[:role], content: msg[:content] }
        end
      end
    end

    private

    def add_message(role, content)
      @messages << { role: role, content: content }
      { role: role, content: content }
    end
  end
end