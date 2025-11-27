# frozen_string_literal: true

require_relative "lib/action_ip_filter/version"

Gem::Specification.new do |spec|
  spec.name = "action_ip_filter"
  spec.version = ActionIpFilter::VERSION
  spec.authors = ["SmartBank, Inc."]
  spec.email = ["common@smartbank.co.jp"]

  spec.summary = "IP address restriction concern for Rails controllers"
  spec.description = "A lightweight concern that allows IP address restrictions on specific controller actions. Unlike Rack middleware solutions, this operates at the controller level for minimal overhead."
  spec.homepage = "https://github.com/smartbank-inc/action_ip_filter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"].reject { |f| File.directory?(f) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails", "~> 8.0"
  spec.add_development_dependency "standard", "~> 1.52"
  spec.add_development_dependency "rails", ">= 8.0"
end
