# OpencBot

#TODO:
-[] specs required - walk through
-[] Notes on incremental search vs iterative search
-[] consider renaming methods to ETL
-[] consider this the canonical source for docs - point template here
-[] example sqlite for checking data
-[] placeholder helper modules
-[] sqlite method examples need expansion
-[x] explain why sqlite
-[] explain about data that stops existing

## Overview

This is a gem to allow bots to be written to fetch and format data that can be easily imported into 
OpenCorporates, the largest openly licensed database of companies in the world. It also aims to be a curated 
set of tools to allow data to be retrieved, formatted and imported on a regular basis.

By including OpencBot you have access to a number of methods for setting up and writing to/reading
from a local SQLite database in which the data can be stored. It is expected to expose two class or module
methods: #update\_data and #export\_data. If the exported data is in the correct format it will be able to
be seamlessly able to be imported into OpenCorporates.

##How to install/create a bot

(This assumes you're using bundler. If not YMMV)

```bash
mkdir your_bot_name
cd your_bot_name
curl -s https://raw.github.com/openc/openc_bot/master/create_bot.sh | bash
```

##Required methods

A bot module or class should look like this:

```ruby
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
```

If you follow the conventions and use these methods (and you must do in order for this to validate)
there are several tasks available to you to run and test the data

    bundle exec openc_bot rake bot:create # creates the bot in the first place
    bundle exec openc_bot rake bot:run # runs the #update_data method
    bundle exec openc_bot rake bot:test # validates that the exported data conforms to the basic data structure expected

## Directory structure

####NB the `data` and `db` directories should not be committed to your bot's Git repo

    root
      |_data # put persistent data in here
      |_db # this is where the sqlite database will be stored. Note that it should not be committed to git, and will be symlinked to a shared directory in production, allowing the database to be persisted through deployments
      |_lib # for the code itself
      |_spec # for the specs
      |_tmp # temporary store. Will not be persisted through deployments

## Why sqlite?

It's important to be able to view and query any data you gather in order to check it's accuracy and quality. We use sqlite as an interim storage method because it has very few external dependencies and works well in this single user environment. See the tips on scraping for more details on how to query/check data with sqlite See the tips on scraping for more details on how to query/check data with sqlite.

## Helper methods
By extending OpencBot, you'll have access to the following methods which may be helpful in obtaining, 
saving and transforming data. More detailed usage is found in the generated code and README for new 
bots.

### Relating to sqlite

**save_data(uniq_keys, values_array, db_name (optional))** - The primary method of saving to the sqlite db.

#### example usage

```ruby
data = [
  {:name => "Acme Corporation Ltd.", :type => "Investment Bank"},
  {:name => "Acme Holdings Ltd.", :type => "Bank Holding Company"}
]
MyBot.save_data([:unique_key, :other_unique_key], data, 'ocdata')
```

This method saves data in an sqlite database named after the name of this class or module.
If no table-name is given the `ocdata` table will be used/created.
The first parameter are names of unique keys, and the data element should be an array of hashes, with keys becoming the field names. 
If the table has not been created or field names are given that are not in the table, they will be created
The save_data method currently saves all values as strings.

  
`insert_or_update`

    Similar but attempts to update the row based on the unique_key

`get_var`
`save_var`

    Allows bot authors to store small bits of information between runs e.g. where a counter was
    up to in a search in case of needing to restart.

`select`

    Convenience method for selecting records for the sqlite db

`save_run_report`

    Used by Open corporates to monitor the status of the bot

### Other
* scrape

    Retrieves a resource from the web and returns a string eg.
    `MyBot.scrape("https://google.com") # returns a string of the page source`

## Format of exported data

 To be written

## General tips on writing a bot

All data sources are different, so the following are just pointers as opposed to rules.

### Break it into stages

Think about breaking the scraping process down into three stages. This is sometimes referred to 
as "Extract, Transform, Load"

"Extract" would mean saving the pages/data to the data folder. "Transform" means loading these files from the 
data folder and parsing them into the right format (probably a hash). The final step, "Load", simply means saving them 
the the database using the `save_data` method.

Saving to disk first provides some benefits in terms of being able to re-run a scraper on failure. It also makes it 
easier to trace if there have been problems with the data.

### Write some specs

Specs aren't 100% required but they can help. Seeing as scraping involves retrieving resources it's best to be careful 
when writing specs that you don't request files every time they run, otherwise you might find yourself getting blocked!
You can achieve this by stubbing out the `scrape` method and returning content from the `spec/dummy_responses` folder 
(see `spec_helper.rb` for details).

### Check with your own eyes

It's always a good idea to look at the data you've collected to see if you're happy with it. There are several good 
sqlite clients available, or alternatively you can use the command line - `sqlite3 path/to/my/database.db`
Check to see for any obvious issues before submitting your bot.

### Documentation, documentation, documentation

You often learn a lot about a domain whilst working on a scraper and it's important that this is saved with the bot. 
Follow the instructions in the generated `README` file and you should be off to a good start. It's important for others 
to be able to review and understand what you've written in case they need to work on it in future.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
