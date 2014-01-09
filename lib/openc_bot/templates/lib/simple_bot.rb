# encoding: UTF-8
require 'simple_openc_bot'

# you may need to require other libraries here
# require 'nokogiri'

class MyLicenceRecord < SimpleOpencBot::BaseLicenceRecord
  # The JSON schema to use to validate records; correspond with files
  # in `schema/*-schema.json`
  schema :licence

  # Fields you define here will be persisted to a local database when
  # 'fetch_records' (see below) is run.
  store_fields :name, :type, :reporting_date

  # This is an array of fields which will uniquely define a record
  # (think primary key in a database)
  unique_fields :name

  # These are just example methods and constants used by
  # `to_pipeline`, below
  JURISDICTION = "uk"
  URL = "http://foo.com"

  def jurisdiction_classification
    type
  end

  # This method must be defined, and should return a timestamp in
  # ISO8601 format. Its value should change when something about
  # the record has changed. If an explicit reporting date is given in
  # the source, use that. If the continued existence of a source is a
  # data point in itself (i.e. indicates the statement still to be
  # true), then a timestamp of the date the page was updated, or the
  # the date the page was scraped, would be appropriate. In the
  # absence of a reporting_date, this will typically be used as the
  # sample_date in the to_pipeline method.
  def last_updated_at
    reporting_date
  end

  # This method must be defined. You can test that you're outputting
  # in the right format with `bundle exec openc_bot rake bot:test`,
  # which will validate against a JSON schema.
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
  # This method should return an array of Records. It must be defined.
  def fetch_records
    # Here we are iterating over an array. Normally you would scrape
    # things from a website and construct LicenceRecords from that.
    data = [
      {:name => "foo",
        :type => "bar",
        :reporting_date => Time.now.iso8601(2)},
      {:name => "foo 2",
        :type => "bar",
        :reporting_date => Time.now.iso8601(2)}
    ]

    # If you scrape using:

    #client = OpencBot::Client.new
    # response = client.get('http://www.google.co.uk/').body
    # ... then response will be cached for you automatically for 24
    # hours, which speeds up debugging quite a lot

    data.map do |datum|
      MyLicenceRecord.new(datum)
    end
  end
end
