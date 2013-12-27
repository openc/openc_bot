#!/bin/bash

set -e

# Add the openc_bot to the Gemfile:
if [ ! -f Gemfile ]; then
  echo "source 'https://rubygems.org'" >> Gemfile
  echo "gem 'openc_bot', :git => 'https://github.com/openc/openc_bot.git', :branch => 'simple-openc-bot'" >> Gemfile
  echo "# Can remove the following line when https://github.com/hoxworth/json-schema/pull/92 is merged" >> Gemfile
  echo "gem 'json-schema', :git => 'git@github.com:sebbacon/json-schema.git', :branch => 'fix-issue-86-allOf'" >> Gemfile
fi
echo "/db" >> .gitignore
echo "/data" >> .gitignore
echo "/tmp" >> .gitignore
bundle install
# create the bot
bundle exec openc_bot rake bot:create_simple_bot
bundle install
