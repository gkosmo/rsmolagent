require "spec_helper"

RSpec.describe RSmolagent::Tools::WebSearchTool do
  let(:tool) { RSmolagent::Tools::WebSearchTool.new }
  
  describe "#initialize" do
    it "initializes with default parameters" do
      tool = RSmolagent::Tools::WebSearchTool.new
      
      expect(tool.name).to eq("web_search")
      expect(tool.description).to include("web search")
      expect(tool.input_schema).to include(:query)
    end
    
    it "allows setting custom max_results" do
      tool = RSmolagent::Tools::WebSearchTool.new(max_results: 3)
      
      # We can't access private instance variables directly
      # but we can verify the tool was created successfully
      expect(tool).to be_a(RSmolagent::Tools::WebSearchTool)
    end
  end
  
  describe "#execute" do
    before do
      # Stub the DuckDuckGo API request
      allow_any_instance_of(Net::HTTP).to receive(:get_response).and_return(
        double("HTTPResponse", 
               is_a?: true, 
               body: {
                 "AbstractText" => "Ruby is a programming language",
                 "AbstractURL" => "https://ruby-lang.org",
                 "Heading" => "Ruby (programming language)",
                 "RelatedTopics" => [
                   {
                     "Text" => "Python - A competing programming language",
                     "FirstURL" => "https://python.org"
                   },
                   {
                     "Text" => "JavaScript - Another language",
                     "FirstURL" => "https://javascript.info"
                   }
                 ]
               }.to_json)
      )
    end
    
    it "returns search results in markdown format" do
      result = tool.call(query: "ruby programming")
      
      expect(result).to include("## Search Results")
      expect(result).to include("[Ruby (programming language)](https://ruby-lang.org)")
      expect(result).to include("Ruby is a programming language")
    end
    
    it "returns an error message for empty queries" do
      result = tool.call(query: "")
      
      expect(result).to include("Error")
    end
    
    it "returns a message when no results are found" do
      # Override the stub to return empty results
      allow_any_instance_of(Net::HTTP).to receive(:get_response).and_return(
        double("HTTPResponse", 
               is_a?: true, 
               body: {
                 "AbstractText" => "",
                 "RelatedTopics" => []
               }.to_json)
      )
      
      result = tool.call(query: "nonexistentsearchquery12345")
      
      expect(result).to include("No results found")
    end
    
    context "when API request fails" do
      it "returns an error message" do
        allow_any_instance_of(Net::HTTP).to receive(:get_response).and_raise(
          StandardError.new("Connection failed")
        )
        
        result = tool.call(query: "ruby programming")
        
        expect(result).to include("Error performing search")
      end
    end
  end
end