#!/bin/bash

set -e

read -e -p "Enter a name for the bot (will create it at $(pwd)): " BOTPATH

if [ "$BOTPATH" != "" ]; then
    mkdir $BOTPATH
    cd $BOTPATH
fi
# Add the openc_bot to the Gemfile:
echo "source 'https://rubygems.org'" >> Gemfile
echo "gem 'openc_bot', :git => 'https://github.com/openc/openc_bot.git'" >> Gemfile
bundle install
# create the bot
bundle exec openc_bot rake bot:create
bundle install
