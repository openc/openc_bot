# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "openc_bot/version"

Gem::Specification.new do |gem|
  gem.name          = "openc_bot"
  gem.version       = OpencBot::VERSION
  gem.authors       = ["Chris Taggart"]
  gem.email         = ["info@opencorporates.com"]
  gem.description   = "This gem is to make the writing and running of bots for OpenCorporates quick and easy"
  gem.summary       = "Helper gem for writing external bots for OpenCorporates"
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)

  # get an array of submodule dirs by executing 'pwd' inside each submodule
  gem_dir = __dir__ + "/"
  `git submodule --quiet foreach pwd`.split($OUTPUT_RECORD_SEPARATOR).each do |submodule_path|
    Dir.chdir(submodule_path) do
      submodule_relative_path = submodule_path.sub gem_dir, ""
      # issue git ls-files in submodule's directory and
      # prepend the submodule path to create absolute file paths
      `git ls-files`.split($OUTPUT_RECORD_SEPARATOR).each do |filename|
        gem.files << "#{submodule_relative_path}/#{filename}"
      end
    end
  end

  gem.executables   = ["openc_bot"]

  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "activesupport"
  gem.add_dependency "backports"
  gem.add_dependency "httpclient"
  gem.add_dependency "json"
  gem.add_dependency "json-schema"
  gem.add_dependency "mail"
  gem.add_dependency "nokogiri", "~> 1.11.1"
  gem.add_dependency "rake"
  gem.add_dependency "resque"
  gem.add_dependency "retriable"
  gem.add_dependency "scraperwiki"
  gem.add_dependency "sqlite_magic"
  gem.add_dependency "statsd-instrument"
  gem.add_dependency "tzinfo"

  # gem.add_development_dependency "perftools.rb"
  gem.add_development_dependency "byebug"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rubocop"
  gem.add_development_dependency "rubocop-rspec"
  gem.add_development_dependency "webmock"
end
