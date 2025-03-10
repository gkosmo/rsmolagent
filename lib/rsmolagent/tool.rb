require 'json'

module RSmolagent
  class Tool
    attr_reader :name, :description, :input_schema

    def initialize(name:, description:, input_schema: {}, output_type: "string")
      @name = name
      @description = description
      @input_schema = input_schema
      @output_type = output_type
    end

    def call(args = {})
      args = args.transform_keys(&:to_sym) if args.is_a?(Hash)
      execute(args)
    end

    def execute(args)
      raise NotImplementedError, "Subclasses must implement the 'execute' method"
    end

    def to_json_schema
      {
        "name" => @name,
        "description" => @description,
        "parameters" => {
          "type" => "object",
          "properties" => formatted_input_schema,
          "required" => required_parameters
        }
      }
    end

    private

    def formatted_input_schema
      result = {}
      @input_schema.each do |name, details|
        result[name.to_s] = {
          "type" => details[:type] || "string",
          "description" => details[:description] || ""
        }
      end
      result
    end

    def required_parameters
      @input_schema.select { |_, details| details[:required] != false }
                  .keys
                  .map(&:to_s)
    end
  end

  class FinalAnswerTool < Tool
    def initialize
      super(
        name: "final_answer",
        description: "Use this to provide the final answer to the task",
        input_schema: {
          answer: {
            type: "string",
            description: "The final answer to the task"
          }
        }
      )
    end

    def execute(args)
      args[:answer].to_s
    end
  end
end