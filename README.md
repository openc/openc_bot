# openc_bot

This is a gem included in each of our external company fetcher bots ([external_bots](https://github.com/openc/external_bots)) providing shared code across all of them.

The gem provides...
* Rake tasks such as `bot:run` for invoking a fetcher run
* The main outer methods involved in executing a fetcher run.
* Methods intended to be overridden to implement a specific bot
* Logic to validate formatted data against openc schemas
* Logic to save an entity to an Sqlite file for import into OpenCorporates
* Helper methods for scraping and iterating over registry websites.
* Resque set-up and worker class for servicing single record update requests.
* Methods to report run progress/completion to the "analysis app" (internal only https://analysis.opencorporates.com)

## External developer documentation
Originally this gem was designed for use by external developers, with OpenCorporates encouraging anyone to join in with writing our bots. Lately we have moved away from that approach, and all meaningful use of this gem is confined to bots living in our own [external bots](https://github.com/openc/external_bots) private repo.

Our **documentation written for external developers**, gives more (out of date) details of what the gem provides and more generally how to write a bot.

* [doc/README-external-devs.md](./doc/README-external-devs.md)
* [doc/README-complex.md](./doc/README-complex.md)
* [doc/SCHEMAS.md](./doc/SCHEMAS.md)

The gem was also originally designed for a variety of bot types, but these days is only used for company fetchers.
