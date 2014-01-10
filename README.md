# OpencBot

## Overview

This is a gem to allow bots to be written to fetch and format data
that can be easily imported into OpenCorporates, the largest openly
licensed database of companies in the world.

The minimum a bot must do is provide four executable files:

 * `bin/fetch_data` - this should attempt to fetch all the data from
   the original source, and store it locally. It should exit with a
   non-zero code and an error message if it is not possible to fetch
   all the data.
 * `bin/export_data` - this should write fetched data to
   `data/<date>/export.json` in the correct JSON format expected by
   OpenCorporates, documented
   [on our wiki](http://wiki.opencorporates.com/bot-schemas). It
   should not re-export data which has previously been exported, but
   has not changed at all.
 * `bin/send_data` - send the latest `export.json` to OpenCorporates
   and log the response
 * `bin/verify_data` - checks the latest `export.json` for errors
   against OpenCorporates' provided JSON schemas

This gem encapsulates a range of functions and utilities to make all
these easy, including the above executables. It also:

 * Persists original response data in a cache, so running your
   methods a second time doesn't take as long
 * Persists fetched and parsed data in an intermediate format in a
   local SQLite database, which helps structure your code,
   particularly when you need to transform it in several steps.

To start writing a new bot, use the following to create stub methods
which we hope will be self-explanatory:

```bash
mkdir your_bot_name
cd your_bot_name
curl -s https://raw.github.com/openc/openc_bot/simple-openc-bot/create_simple_licence_bot.sh | bash
```

The default bot scrapes a dummy page on our website. Examine the bot
code created at `your_bot_name/lib/your_bot_name.rb` and read the
comments there.  Please also read the rest of this documentation.

You can write bots for any schemas we have defined - see
[SCHEMAS.md](./SCHEMAS.md)

You can try running the scraper with `bin/fetch_data`, testing its
output with `bin/verify_data`, and `bin/export_data` to write the data
to the `data/` directory.

For more complicated scrapers, you may wish to do things more manually
-- see [README-complex.md](./README-complex.md) for more info.

# A few words about dates

There are three kinds of dates that OpenCorporates deals with:

1. The date on which an observation was true: the `sample_date`. This
is the date of a bot run, or a reporting date given in the source
document. Every observation **must have a sample date**.
2. A `start_date` and/or `end_date` defined explicitly in the source
document
3. A `start_date` or `end_date` that has not been provided by the
source, but which OpenCorporates can infer from one or more sample
dates. *In this case, you just supply a sample_date, and we do the
rest*

All dates should be in ISO8601 format.

## A few more words about dates to explain

One of the important parts of the data format expected by
OpenCorporates are the dates a statement is known to be true.

All statements can be considered to be true between a start date and
an end date. Sources that make explicit statements like this are great
- but they're rare. For sources that don't explicitly define start and
end dates for statements, it is down to OpenCorporates to compute
these based on the bot's run schedule, and sample dates in the source
data.

Imagine you are interested in mining licenses in Liliput and
Brobdingnag, and you want to provide this data to OpenCorporates. You
find a website that lists mining licenses for these jurisdictions, so
you write a bot that can submit each license.

You find that Liliputian licenses have a definied start date and a
definied end date, which mean you can explicitly say "this license is
valid between 1 June 2012 and 31 Aug 2013" for a particular license.

In this case, you would submit the data with a `start_date` of
`2012-06-01` and an `end_date` of `2013-08-31`; and a
`start_date_type` of `=` and an `end_date_type` of `=`. You would
also submit a `sample_date` for that document, which is the date on
which the license was known to be current (often today's date, but
sometimes the reporting date given in the source).

However, you find that Brobdingnagian licenses only tell you currently
issued licenses. As a bot writer, all you can say of a particular
license is "I saw this license when we ran the bot on 15 January
2012". In this case, you would leave `start_date` and `end_date`
blank, and submit a `sample_date` of `2012-01-15` instead.

If you subsequently see the license on 15 February, you'd submit
exactly the same data with a new `sample_date`.

A bot is expected to be run periodically, at intervals relevant to its
source. For example, a bot that scrapes data which changes monthly should
scrape at least monthly. You should indicate this in the bot's
`config.yml` file.

This means OpenCorporates can infer, based on the running schedule of
the bot, and the `sample_date`s of its data, the dates between which a
license was valid (in this case, between 15 January and 15 February).

# Speeding up your tests

When writing scrapers, it's common to find yourself repeatedly
scraping data from a source as you iteratively improve your code. It
can be useful to use a caching proxy on your development machine to
speed up this cycle.

If you run `bin/fetch_data --test`, then your `fetch_records` method
will receive an option `test_mode`; you can use this to turn proxying
on or off.  The example scraper created by the bot creation script
shows how you would do this using `mechanize`; if you want to use
different http client libraries, refer to their documentation
regarding how to set a proxy.  Here's the mechanize version:

    agent = Mechanize.new
    if opts[:test_mode]
      # this requires you to have a working proxy set up -- see
      # README.md for notes. It can speed up development considerably.
      agent.set_proxy 'localhost', 8123
    end

To make this work, you will also want to set up a caching proxy
listening on `localhost:8123`.  One such lightweight proxy is
[polipo](http://www.pps.univ-paris-diderot.fr/~jch/software/polipo/),
which is available packaged for various platforms.  The following
options in the config work for us:

    cacheIsShared = false
    disableIndexing = false
    disableServersList = false
    relaxTransparency = yes
    dontTrustVaryETag = yes
    proxyOffline = no
