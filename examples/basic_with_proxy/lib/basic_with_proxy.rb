# encoding: UTF-8
require 'simple_openc_bot'
require 'mechanize'

# you may need to require other libraries here
# require 'nokogiri'

class BasicWithProxyRecord < SimpleOpencBot::BaseLicenceRecord
  # The JSON schema to use to validate records; correspond with files
  # in `schema/*-schema.json`
  schema :licence

  # Fields you define here will be persisted to a local database when
  # 'fetch_records' (see below) is run.
  store_fields :name, :type, :reporting_date

  # This is the field(s) which will uniquely define a record (think
  # primary key in a database).
  unique_fields :name

  # These are just example methods and constants used by
  # `to_pipeline`, below
  JURISDICTION = "uk"
  URL = "http://foo.com"

  def jurisdiction_classification
    type
  end

  # This must be defined, and should return a timestamp in ISO8601
  # format. Its value should change when something about the record
  # has changed. It doesn't have to be a method - it can also be a
  # member of `store_fields`, above.
  def last_updated_at
    reporting_date
  end

  # This method must be defined. You can test that you're outputting
  # in the right format with `bin/verify_data`, which will validate
  # any data you've fetched against the relevant schema. See
  # `doc/SCHEMA.md` for documentation.
  def to_pipeline
    {
      sample_date: last_updated_at,
      company: {
        name: name,
        jurisdiction: JURISDICTION,
      },
      source_url: URL,
      data: [{
        data_type: :licence,
        properties: {
          jurisdiction_code: JURISDICTION,
          category: 'Financial',
          jurisdiction_classification: [jurisdiction_classification],
        }
      }]
    }
  end

end

class BasicWithProxy < SimpleOpencBot

  # the class that `fetch_records` yields. Must be defined.
  yields BasicWithProxyRecord

  # This method should yield Records. It must be defined.
  def fetch_all_records(opts={})

    # you can use any client here, e.g. HTTPClient, open-uri, etc.
    agent = Mechanize.new

    # This option is set to true when the rake task is called with a
    # --test switch
    if opts[:test_mode]
      # It is recommended to set up a proxy on your computer when
      # developing and debugging bots. It can greatly speed things up
      # by removing the network time from the equation (though things
      # like POSTs won't be cached, anyway)

      # Different agents have different ways of setting a proxy. This
      # is how Mechanize does it:
      agent.set_proxy 'localhost', 8123
    end

    # This is a live page on our website - have a look to see what's
    # going on. If you have a proxy set up on your computer, the
    # second time you run this bot, the website won't get hit.
    page = agent.get("http://assets.opencorporates.com/test_bot_page.html")

    # We tend to use Nokogiri to parse responses, but again this is up
    # to you.
    doc = Nokogiri::HTML(page.body)
    doc.xpath("//li").map do |li|
      name, type = li.content.split(":")
      yield BasicWithProxyRecord.new(
        :name => name.strip,
        :type => type.strip,
        :reporting_date => Time.now.iso8601(2))
    end
  end
end
