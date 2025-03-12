Gem::Specification.new do |spec|
  spec.name          = "rsmolagent"
  spec.version       = "0.1.0"
  spec.authors       = ["gkosmo"]
  spec.email         = ["gkosmo1@hotmail.com"]

  spec.summary       = "A simple AI agent framework in Ruby"
  spec.description   = "RSmolagent is a Ruby library for building AI agents that can use tools to solve tasks"
  spec.homepage      = "https://github.com/gkosmo/rsmolagent"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[lib/**/*.rb LICENSE.txt README.md])
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "json", "~> 2.0"
  
  # Optional dependencies for examples
  spec.add_development_dependency "ruby-openai", "~> 6.0"
  spec.add_development_dependency "anthropic", "~> 0.3.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end