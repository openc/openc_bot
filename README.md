# OpencBot

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

####NB the `data` and `db` directories are excluded by default in .gitignore

    root
      |_data # put persistent data in here
      |_db # this is where the sqlite database will be stored. Note that it should not be committed to git, and will be symlinked to a shared directory in production, allowing the database to be persisted through deployments
      |_lib # for the code itself
      |_spec # for the specs
      |_tmp # temporary store. Will not be persisted through deployments

## How to export the data

### Description of output format

We expect licence data as a hash with the following keys:

    :sample_date
        required (if end_date is not provided)
    :start_date
        optional
    :start_date_type
        required if :start_date is present
        one of "at", "before", or "after"
    :end_date
        optional (if sample_date is provided)
    :end_date_type
        required if :end_date is present
        one of "at", "before", or "after"
    :company
        required
        a hash with the following keys:
            :name
                required
                a string of the name of the company
            :jurisdiction
                required
                a string of the jurisdiction
                    eg "us_ca"
    :source_url
        required
        a string of the URL of the data
    :data
        required
        an array with a single hash, with the following keys:
            :data_type
                required
                must be :licence
            :properties
                required
                a hash with the following keys:
                    :category
                        required
                        should be "Financial" -- contact OC if this doesn't apply
                    :jurisdiction_role
                        required
                        a string describing the role of the licensed company within the jurisdiction
                            for instance "Bank", "Insurer", "Trust Company"
                    :licence_number
                        optional
                    :description
                        optional
                        a string with a description of the licence from the data source
                    :permissions
                        optional
                        an array of strings listing the permissions that are granted by the licence

### What to do when data no longer exists

It is difficult to  accomodate every type of variation in how data can be classified as 'fresh' or 'out of date' and 
so on. This means that we need help from bot authors in identifying when data is no longer valid.

This will usually mean that you will have to timestamp records for each run, making sure to update the timestamp of 
records that are still available but haven't changed. After each run you may find that some records have "dropped off" 
the source and are no longer available/valid. *For these records* the thing to do when something stops being true 
is to post it with an identical `:properties` as above but with an `:end_date` of `today` and `:end_date_type` of `"before"`, 
*INSTEAD* of a `sample date`.

*For all the current records that are otherwise unchanged* you should still submit them with a new `sample_date` so 
that we know they are still current.

## General tips on writing a bot

All data sources are different, so the following are just pointers as opposed to rules.

### Break it into stages

Think about breaking the scraping process down into three stages. This is sometimes referred to 
as "Extract, Transform, Load"

"Extract" would mean saving the pages/data to the data folder. "Transform" means loading these files from the 
data folder and parsing them into the right format (probably a hash). The final step, "Load", simply means saving them 
the the database using the `save_data` method.

#### Example: Extract

```ruby
module MyBot
  extend self
  SOURCE_FILE_URL = 'http://www.dfi.utah.gov/Download/INSTADDR.TXT'

  # ... other methods

  def extract
    src = MyBot.scrape(SOURCE_FILE_URL)
    outfile =  File.expand_path("../data/utah_institutions_file.txt", File.dirname(__FILE__))

    File.open(outfile, "w") {|f| f.write src}
  end

  # ... other methods
end
```

Saving to disk first provides some benefits in terms of being able to re-run a scraper on failure. It also makes it 
easier to trace if there have been problems with the data.

#### Example: Transform

```ruby
module MyBot
  extend self

  # ... 

  def transform
    src_path =  File.expand_path("../data/utah_institutions_file.txt", File.dirname(__FILE__))
    src = IO.read(src_path)

    CSV.parse(src, :headers => true).collect do |row|
      new_row = row.merge(:retrieved_at => Time.now)
      new_row[:company_name] = row[:name].gsub(/[[:space:]]+/, ' ') # for example
      new_row # this is now a data hash ready for import
    end
  end

  # ...
end
```

This is a very simple example. You will probably need to break out the process into more methods, but 
consider keeping them "wrapped" in a transform method so that you and other scraper authors can see what 
is going on in future.

#### Example: Load

```ruby
module MyBot
  extend self

  # ... 

  def load
    data = transform # from our previous example
    save_data([:uniq_id_field], data)
  end

end
```

This is fairly straightforward using one of the included helper methods (see ["Helper methods"](#helper-methods)).

*Why sqlite?* It's important to be able to view and query any data you gather in order to check it's 
accuracy and quality. We use sqlite as an interim storage method because it has very few external 
dependencies and works well in this single user environment. See the ["Working with sqlite"](#working-with-sqlite) section for more details 
on how to query/check data with sqlite See the tips on scraping for more details on how to query/check data with sqlite.

### Write some specs

*Specs are 100% required* :smiley_cat:. If nothing else, specs help to explain what you were trying to do with a particular method.

Seeing as scraping involves retrieving resources it's best to be careful 
when writing specs that you *don't request files from the web every time they run*, otherwise you might find yourself getting blocked!
You can achieve this by stubbing out the `scrape` method and returning content from the `spec/dummy_responses` folder 
(see `spec_helper.rb` for details).

#### BAD spec

```ruby
describe MyBot do

  it "should parse a HTML file" do
    response = MyModule.scrape("http://my-interesting-data-source.com")
    MyBot.parse(response).should_not be_empty
  end

  # NO - this will hit the network every time you run the test
  # not only is this slow, but you're putting unnecessary load
  # on the data source

end
```

#### GOOD spec

```ruby
describe MyBot do

  before :each do
    MyBot.stub(:scrape).and_return(dummy_reponse('path/to/saved/html/response/in/spec/dummy_responses/sample.html'))
  end

  it "should parse a HTML file" do
    response = MyModule.scrape("http://my-interesting-data-source.com")
    MyBot.parse(response).should_not be_empty
  end

  # YES - this only uses a file on your local disk
  # This makes for a very fast test - the only downside is
  # that you have to keep your sample responses up to date
  # if they change (html layout for example) on the data source.
  # `stub` will change the method that you pass in, making sure that
  # it's original doesn't get called, but also checking that the new 
  # dummy method will.
  # `and_return` is a way of simulating what that method would have responded with
  # `dummy_response` is defined in the sample spec_helper.rb file

end
```

For general advice on using RSpec, there is a good slide deck here: [http://kerryb.github.io/iprug-rspec-presentation/](http://kerryb.github.io/iprug-rspec-presentation/)
For general RSpec style guidelines, [http://betterspecs.org/](http://betterspecs.org/) is worth a read.

### Check with your own eyes

It's always a good idea to look at the data you've collected to see if you're happy with it. There are several good 
sqlite clients available, or alternatively you can use the command line - `sqlite3 path/to/my/database.db`
Check to see for any obvious issues before submitting your bot.

### Documentation, documentation, documentation

You often learn a lot about a domain whilst working on a scraper and it's important that this is saved with the bot. 
Follow the instructions in the generated `README` file and you should be off to a good start. It's important for others 
to be able to review and understand what you've written in case they need to work on it in future.

## Other things to consider

### What category is your scraper?

**Simple** - retrieving a static file in a standard format (e.g. CSV)

**Incremental** - scraping a site by incrementing some id parameter eg. a query string param `?id=47`

**Iterative** - working over a range of possible inputs eg. searching for all the letters from `a..z`

Each of these have their separate challenges and some data sources require a combination of all three. With the 
incremental and iterative steps, it's a good idea to keep track of where you are up to in case you need to stop/restart 
the bot (see the `get_var` and `save_var` example in [Helper methods](#helper-methods)).

## Working with sqlite

This bot includes a copy of the sqlite3 *gem*, but you might need to install the sqlite3 program using your 
package manage (`brew`, `apt-get`, `yum` etc.)

In the root folder of your bot, you should be able to run 

```bash
sqlite3 db/mybotname.db
```

where `mybotname` is the name of your bot. This will open up an sql prompt. A few useful commands:

#### .help
#### .tables

These will let you know what to do in most cases. Commands beginning with a dot (`.`) have a special meaning 
in the sqlite prompt.

#### .mode line

Nice format for reviewing records at the shell

```sql
sqlite> SELECT * FROM us_nj_banks ORDER BY RANDOM() LIMIT 2;
```

```
        licensee_name = RICHARDSON IMPORTS INC
              ref_num = 8901006
business_name_address = RICHARDSON IMPORTS INC1230 ROUTE 73MOUNT LAUREL, NJ 08054
         license_type = MOTOR VEHICLE INSTALLMENT SELLER (CORPORATION)
               status = ACTIVELY LICENSED

        licensee_name = ISAAC,RHONDA
              ref_num = 0805480
business_name_address = EMPIRE TODAY LLC1200 TAYLORS LANESUITE 2BCINNAMINSON, NJ 08077
         license_type = HOME REPAIR SALESMAN
               status = ACTIVELY LICENSED
```

#### .output result.html
#### .mode html

Potentially useful way of reviewing larger numbers of records without a dedicated sqlite program. You have to 
add in the opening and closing table tags yourself though.

```sql
sqlite> SELECT * FROM us_nj_banks ORDER BY RANDOM() LIMIT 100;

-- This would output 100x <tr> tags into a file called result.html in the project root
```

## Helper methods
By extending OpencBot, you'll have access to the following methods which may be helpful in obtaining, 
saving and transforming data. More detailed usage is found in the generated code and README for new 
bots.

### Relating to sqlite

**save_data ( uniq_keys, values_array, table_name='ocdata' )** - The primary method of saving to the sqlite db.

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

**insert_or_update ( uniq_keys, values_array, table_name='ocdata' )** - Update/insert data based on existing key sqlite db.

Similar to `save_data` but attempts to update the row based on the unique_key

**save_var ( name, value )** - save a value to the database

**get_var ( name, default=nil )** - retrive a value, with a fallback if it doesn't exist

```ruby
current_id = MyBot.get_var('current_id', 1) # get the last good id, otherwise return 1
long_scraping_process.each do |page|
  save_to_disk(page)
  MyBot.save_var(current_id)
  current_id += 1
end
```

Allows bot authors to store small bits of information between runs. Unfortunately long running bots tend
to get stopped unexpectedly in development (power cuts, connectivity failures etc.) so these methods are 
useful in picking up where you left off.

**select ( sqlquery )** - Convenience method for selecting records for the sqlite db

```ruby
MyBot.select('* from ocdata') # return everything
```

**save_run_report ( reporthash )** - To be called at the end of each run

```ruby
MyBot.update_data
  super_complicated_scrape_task
  save_run_report(:status => 'success')
end
```

Used by Open corporates to monitor the status of the bot. 
Please include relevant information such as failures and error messages in the report hash.
`Time.now` is added to the output automatically.

### Other
**scrape ( url, params=nil, agent=nil )** - fetches content from a webserver

```ruby
MyBot.scrape("https://google.com") # returns a string of the page source
```

Retrieves a resource from the web and returns a string. Uses the HTTPClient gem internally which 
handles SSL and gzipped content.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
