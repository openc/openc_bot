#!/bin/bash

set -e

# Add the openc_bot to the Gemfile:
if [ ! -f Gemfile ]; then
  echo "source 'https://rubygems.org'" >> Gemfile
  echo "gem 'openc_bot', :git => 'https://github.com/openc/openc_bot.git', :branch => 'enumerators-and-iterators'" >> Gemfile
  echo "gem 'mechanize'" >> Gemfile
fi
echo "/db" >> .gitignore
echo "/data" >> .gitignore
echo "/tmp" >> .gitignore
bundle install
# create the bot
bundle exec openc_bot rake bot:create_simple_bot
bundle install
