# encoding: UTF-8
require 'simple_openc_bot'
require 'mechanize'

# you may need to require other libraries here
# require 'nokogiri'

class MyLicenceRecord < SimpleOpencBot::BaseLicenceRecord
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
  # any data you've fetched against the relevant schema.
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
          category: 'Financial',
          jurisdiction_classification: [jurisdiction_classification],
        }
      }]
    }
  end

end

class MyLicence < SimpleOpencBot

  # the class that `fetch_records` yields
  yields MyLicenceRecord

  # This method should yield Records. It must be defined.
  def fetch_all_records(opts={})
    agent = Mechanize.new
    page = agent.get("http://assets.opencorporates.com/test_bot_page.html")
    doc = Nokogiri::HTML(page.body)
    doc.xpath("//li").map do |li|
      name, type = li.content.split(":")
      yield MyLicenceRecord.new(
        :name => name.strip,
        :type => type.strip,
        :reporting_date => Time.now.iso8601(2))
    end
  end
end
