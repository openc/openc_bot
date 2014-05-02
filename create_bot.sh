#!/bin/bash

set -e

# Add the openc_bot to the Gemfile:
if [ ! -f Gemfile ]; then
  echo "source 'https://rubygems.org'" >> Gemfile
  echo "gem 'openc_bot', :git => 'https://github.com/openc/openc_bot.git'" >> Gemfile
fi

echo "/db/*" >> .gitignore
echo "/data/*" >> .gitignore
echo "/tmp/*" >> .gitignore
echo "/pids/*" >> .gitignore
echo "!.gitkeep" >> .gitignore

mkdir -p db
mkdir -p data
mkdir -p tmp
mkdir -p pids

touch db/.gitkeep
touch data/.gitkeep
touch tmp/.gitkeep
touch pids/.gitkeep

bundle install
# create the bot
bundle exec openc_bot rake bot:create
bundle install
