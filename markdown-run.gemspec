# frozen_string_literal: true

require_relative "lib/markdown/run/version"

# add rcodetools as a gem dependency
#
Gem::Specification.new do |spec|
  spec.name = "markdown-run"
  spec.version = Markdown::Run::VERSION
  spec.authors = [ "Aurélien Bottazini" ]
  spec.email = [ "32635+aurelienbottazini@users.noreply.github.com" ]

  spec.summary = "Run code blocks in Markdown files"
  spec.description = "Run code blocks in Markdown files for Ruby, JavaScript, sqlite, psql, bash, zsh, and mermaid. Insert execution results next to the original code blocks. Generate SVG diagrams from mermaid blocks."
  spec.homepage = "https://github.com/aurelienbottazini/markdown-run"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"


  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/aurelienbottazini/markdown-run"
  spec.metadata["changelog_uri"] = "https://github.com/aurelienbottazini/markdown-run/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        (f.start_with?('docs/') && f.end_with?('.gif'))
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  spec.add_dependency 'rcodetools', '0.8.5'
  spec.add_dependency 'ostruct', '0.6.1'

  spec.add_development_dependency 'minitest', "5.25.5"
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'flog'
  spec.add_development_dependency 'simplecov', '~> 0.22'

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
