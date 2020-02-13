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

  gem.required_ruby_version = "~> 2.2.0"
  gem.add_dependency "activesupport", "~> 4.1"
  gem.add_dependency "backports", "~> 3.11"
  gem.add_dependency "httpclient", "~> 2.8"
  gem.add_dependency "json", "~> 2.1"
  gem.add_dependency "json-schema", "~> 2.8"
  gem.add_dependency "mail", "~> 2.0"
  gem.add_dependency "nokogiri", "~> 1.8"
  gem.add_dependency "rake", "~> 12.3"
  gem.add_dependency "retriable", "~> 2.1"
  gem.add_dependency "scraperwiki", "3.0.2"
  gem.add_dependency "sqlite_magic", "0.0.6"
  gem.add_dependency "tzinfo", "~> 1.2"

  # gem.add_development_dependency "perftools.rb"
  gem.add_development_dependency "byebug", "~> 10.0"
  gem.add_development_dependency "rspec", "~> 3.8"
  gem.add_development_dependency "rubocop", "~> 0.55"
  gem.add_development_dependency "rubocop-rspec", "~> 1.30"
  gem.add_development_dependency "webmock", "~> 1.20"
end
