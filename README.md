# OpencBot

## Overview

This is a gem to allow bots to be written to fetch and format data
that can be easily imported into OpenCorporates, the largest openly
licensed database of companies in the world.

To start writing a new bot, run the following to create a skeleton bot:

```bash
mkdir your_bot_name
cd your_bot_name
curl -s https://raw.github.com/openc/openc_bot/master/create_simple_licence_bot.sh | bash
```

The default bot scrapes a dummy page on OpenCorporates'
website. Once you've set it up, you can try:

* running the scrape with `bundle exec openc_bot rake bot:run`
* testing the validity of the data it will output with
  `bundle exec openc_bot rake bot:test`

Finally, take a look at the bot code created at
`your_bot_name/lib/your_bot_name.rb` and read the comments there to
start writing your own bot.  First, get it scraping correctly (which
you can test by repeatedly running `bin/fetch_data`); second,
transform the scraped data correctly (which you can test with
`bin/verify_data`). You can write bots for any schemas we have
defined - see [SCHEMAS.md](./doc/SCHEMAS.md) for currently supported
schemas.

When you are happy that your bot is finished, please update its
`README.md`, change the `enabled` flag in `config.yml` to be `true`,
and email us.

Please note that dates are a bit complicated, so we ask you to read
the notes below carefully.

## About fetching and transforming data

As you'll see in the sample bot, bots have separate steps to fetch
data (the `fetch_records` method) and to transform it to a format
suitable for OpenCorporates (the `to_pipeline` method).

It is useful to have separate *fetch* and *export* phase for a couple
of reasons:

* For very large source datasets, it can take months to complete a
  scrape. It is then useful to verify the data quality before
  ingesting it in OpenCorporates.
* Often, datasets may include a load of potentially interesting data
  which OpenCorporates doesn't yet support.  It's worth storing this
  data in an intermediate format, to save having to scrape it again in
  the future. Please save anything like that and make a note of it in
  your `README.md`.

For more complicated scrapers, you may wish to do things more manually
-- see [README-complex.md](./doc/README-complex.md) for more info.

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

## A few more words about dates

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

Hence the above.

# Speeding up your tests

When writing scrapers, it's common to find yourself repeatedly
scraping data from a source as you iteratively improve your code. It
can be useful to use a caching proxy on your development machine to
speed up this cycle.

If you run `bin/fetch_data --test`, then your `fetch_records` method
will receive an option `test_mode`; you can use this to turn proxying
on or off.  Here's how you can set a proxy using the `mechanize`
library; if you want to use different http client libraries, refer to
their documentation regarding how to set a proxy.

    agent = Mechanize.new
    if opts[:test_mode]
      # this requires you to have a working proxy set up -- see
      # README.md for notes. It can speed up development considerably.
      agent.set_proxy 'localhost', 8123
    end
    agent.get("http://www.foo.com") # will get it from local cache the second time

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
