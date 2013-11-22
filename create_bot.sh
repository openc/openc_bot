#!/bin/bash

set -e

# Add the openc_bot to the Gemfile:
echo "source 'https://rubygems.org'" >> Gemfile
echo "/db" >> .gitignore
echo "/data" >> .gitignore
echo "gem 'openc_bot', :git => 'https://github.com/openc/openc_bot.git'" >> Gemfile
bundle install
# create the bot
bundle exec openc_bot rake bot:create
bundle install
