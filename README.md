# OpencBot

This is a gem to allow bots to be written to fetch and make available data that can easily be imported into OpenCorporates, the largest openly licensed database of companies in the world.

By including OpencBot you have access to a number of methods for setting up and writing to/reading
from a local SQLite database in which the data can be stored. It is expected to expose two class or module
methods: #update\_data and #export\_data. If the exported data is in the correct format it will be able to
be seamlessly able to be imported into OpenCorporates.

##How to install/create a bot

(This assumes you're using bundler. If not YMMV)

    mkdir my_bot # the bot will be named after the name of this directory
    cd my_bot
    bundle init
    # Add the openc_bot to the Gemfile:
    echo "gem 'openc_bot', :git => 'git@github.com:openc/openc_bot.git'" > Gemfile
    bundle install
    # create your bot
    bundle exec openc_bot rake bot:create


##Usage

A bot module or class should look like this:

    Module MyBot
      extend OpencBot
      extend self

      def update_data
        # fetch or scrape data and store in local SQLite database
      end

      def export_data(options={})
        # return data (possibly from the SQLite database)
      end
    end

If you follow the conventions and use these methods (and you must do in order for this to validate)
there are several tasks available to you to run and test the data

bundle exec openc_bot rake bot:create # creates the bot in the first place
bundle exec openc_bot rake bot:run # runs the #update_data method
bundle exec openc_bot rake bot:test # validates that the exported data conforms to the basic data structure expected

## Format of exported data

 To be written

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

