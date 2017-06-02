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

  # get an array of submodule dirs by executing 'pwd' inside each submodule
  gem_dir = File.expand_path(File.dirname(__FILE__)) + "/"
  `git submodule --quiet foreach pwd`.split($\).each do |submodule_path|
    Dir.chdir(submodule_path) do
      submodule_relative_path = submodule_path.sub gem_dir, ""
      # issue git ls-files in submodule's directory and
      # prepend the submodule path to create absolute file paths
      `git ls-files`.split($\).each do |filename|
        gem.files << "#{submodule_relative_path}/#{filename}"
      end
    end
  end

  gem.executables   = ['openc_bot']

  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "rake"
  gem.add_dependency "activesupport", "~> 4.1"
  if RUBY_VERSION < '2.1'
    gem.add_dependency "nokogiri", "< 1.7.0"
  else
    gem.add_dependency "nokogiri"
  end
  gem.add_dependency "sqlite_magic", "0.0.6"
  gem.add_dependency "json"
  gem.add_dependency "json-schema"
  gem.add_dependency "httpclient"
  gem.add_dependency "backports"
  gem.add_dependency "scraperwiki", "3.0.2"
  gem.add_dependency "mail", "~> 2.0"
  gem.add_dependency "retriable", "~> 2.1"
  gem.add_dependency "tzinfo"
  # gem.add_dependency "openc-asana" unless RUBY_VERSION < '2.0'
  if RUBY_VERSION < '2.0'
    gem.add_dependency "addressable", "< 2.5.0" # via `json-schema`
    gem.add_dependency "mime-types", "< 3.0" # via `mail`
  end

  # gem.add_development_dependency "perftools.rb"
  gem.add_development_dependency "byebug" unless RUBY_VERSION < '2.0'
  gem.add_development_dependency "debugger" if RUBY_VERSION < '2.0'
  gem.add_development_dependency "rspec"
end
