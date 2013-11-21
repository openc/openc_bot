# encoding: UTF-8
# NB You should run the bot in a directory containing a Gemfile, which should contain the following line:
# gem 'openc_bot', :git => 'git@github.com:openc/openc_bot.git'
# so that you can, collect the gems using bundler.
require 'openc_bot'

# you may need to require other libraries here
#
# require 'nokogiri'

module MyModule
  extend OpencBot
  extend self # make these methods as Module methods, rather than instance ones

  def export_data(params={:offset => 0})
    # This is the basic functionality for exporting the data from the database. By default the data
    # table (what is created when you save_data) is called ocdata, but it can be called anything else,
    # and the query can be more complex, returning, for example, only the most recent results.
    # By default the importer will page through the data, supplying an offset equal to the aggregate
    # number of results already received. It will stop requesting data when an empty array is returned
    sql_query = "ocdata.* from ocdata LIMIT 200 OFFSET #{params[:offset]}"
    select(sql_query).collect do |raw_datum|
      # raw_datum will be a Hash of field names (as symbols) for the keys and the values for each field.
      # It should be converted to the format necessary for importing into OpenCorporates, perhaps by
      # using a prepare_for_export method.
      prepare_for_export(raw_datum)
    end
  end



  def prepare_for_export(raw_data)
    # do something here to convert the raw data from the database (if you are using one) into
    # the form required by the export.
  end

  def update_data
    # write code here (using other methods if necessary) for 
    # updating your local database with data from the source 
    # that you are scraping or fetching from
    #
    # # See https://github.com/openc/openc_bot README for details
    # save_data([:uid,:date], my_data, sometablename)
    #
    # After updating the data you should run save_run_report, which 
    # saves the status (and other data, if applicable)
    save_run_report(:status => 'success')
  end

end
