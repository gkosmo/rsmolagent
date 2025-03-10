require 'net/http'
require 'json'
require 'uri'
require 'cgi'

module RSmolagent
  module Tools
    class WebSearchTool < Tool
      def initialize(max_results: 5)
        super(
          name: "web_search",
          description: "Performs a web search based on your query (like a Google search) and returns the top search results",
          input_schema: {
            query: {
              type: "string",
              description: "The search query to perform"
            }
          }
        )
        @max_results = max_results
      end

      def execute(args)
        query = args[:query]
        
        # Ensure query isn't empty
        return "Error: Search query cannot be empty" if query.nil? || query.strip.empty?
        
        begin
          results = search_duckduckgo(query)
          
          if results.nil? || results.empty?
            return "No results found for query: '#{query}'. Try a less restrictive/shorter query."
          end
          
          # Format the results as markdown
          formatted_results = format_results(results)
          return "## Search Results\n\n#{formatted_results}"
        rescue => e
          return "Error performing search: #{e.message}"
        end
      end

      private

      def search_duckduckgo(query)
        # Use the DuckDuckGo API
        encoded_query = CGI.escape(query)
        uri = URI("https://api.duckduckgo.com/?q=#{encoded_query}&format=json")
        
        response = Net::HTTP.get_response(uri)
        
        if response.is_a?(Net::HTTPSuccess)
          # Parse the response
          data = JSON.parse(response.body)
          
          # Extract results
          results = []
          
          # Get results from "AbstractText" if available
          if data["AbstractText"] && !data["AbstractText"].empty?
            results << {
              title: data["Heading"],
              url: data["AbstractURL"],
              body: data["AbstractText"]
            }
          end
          
          # Get results from "RelatedTopics"
          if data["RelatedTopics"]
            data["RelatedTopics"].each do |topic|
              next if topic["Text"].nil? || topic["FirstURL"].nil?
              
              # Extract title from the text (first few words)
              text_parts = topic["Text"].split(" - ", 2)
              title = text_parts.first || "Related Topic"
              body = text_parts.last || text_parts.first
              
              results << {
                title: title,
                url: topic["FirstURL"],
                body: body
              }
            end
          end
          
          # Limit results to max_results
          return results.first(@max_results)
        else
          raise "Request failed with status: #{response.code}"
        end
      end

      def format_results(results)
        results.map do |result|
          "[#{result[:title]}](#{result[:url]})\n#{result[:body]}"
        end.join("\n\n")
      end
    end
  end
end