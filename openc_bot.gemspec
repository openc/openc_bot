# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openc_bot/version'

Gem::Specification.new do |gem|
  gem.name          = "openc_bot"
  gem.version       = OpencBot::VERSION
  gem.authors       = ["Chris Taggart"]
  gem.email         = ["info@opencorporates.com"]
  gem.description   = %q{This gem is to make the writing and running of bots for OpenCorporates quick and easy}
  gem.summary       = %q{Helper gem for writing external bots for OpenCorporates}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)

  gem.executables   = ['openc_bot','turbot']

  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib",'lib/openc_bot/helpers']

  gem.add_dependency "rake"
  gem.add_dependency "activesupport", "3.2.17"
  gem.add_dependency "nokogiri"
  # gem.add_dependency "sqlite3"
  gem.add_dependency "json"
  gem.add_dependency "json-schema"
  gem.add_dependency "httpclient"
  gem.add_dependency "backports"
  gem.add_dependency "scraperwiki"
  gem.add_dependency "rubyzip"


  gem.add_development_dependency "perftools.rb"
  gem.add_development_dependency "debugger"
  gem.add_development_dependency "rspec"
end
