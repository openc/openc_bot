# encoding: UTF-8
require 'openc_bot'
require 'openc_bot/company_fetcher_bot'

# you may need to require other libraries here
#
# require 'nokogiri'
# require 'openc_bot/helpers/dates'

module MyModule
  extend OpencBot
  # This adds the CompanyFetcherBot functionality
  extend OpencBot::CompanyFetcherBot
  extend self # make these methods as Module methods, rather than instance ones

  # If the register has a GET'able URL based on the company_number define it here. This should mean that
  # #fetch_datum 'just works'.
  def computed_registry_url(company_number)
    # e.g.
    # "http://some,register.com/path/to/#{company_number}"
  end

  # This is the primary method for getting companies from the register. By default it uses the #fetch_data
  # method defined in IncrementalSearch helper module, which increments through :company_number identifiers.
  # See helpers/incremental_search.rb for details
  # Override this if a different method for iterating companies is going to done (e.g. an alpha search, or
  # parsing a CSV file)
  def fetch_data
    fetch_data_via_incremental_search
  end

  # This is called by #update_datum (defined in the IncrementalSearch helper module), which updates the
  # information for a given company_number. This allows the individual records to be updated, for example,
  # via the 'Update from Register' button on the company page on OpenCorporates. This method is also called
  # by the #fetch_data method in the case of incremental_searches.
  # By default it calls #fetch_registry_page with the company_number and returns the result in a hash,
  # with :company_page as a key. This will then be processed or parsed by the #process_datum method,
  # and the result will be saved by #update_datum, and also returned in a form that can be used by the
  # main OpenCorporates system
  # This hash can contain other data, such as a page of filings or shareholdings, and the hash will be
  # converted to json, and stored in the database in the row for that company number, under the :data key,
  # so that it can be reused or referred it in the future.
  # {:company_page => company_page_html, :filings_page => filings_page_html}
  def fetch_datum(company_number)
    super
  end

  # This method must be defined for all bots that can fetch and process individual records, including
  # incremental, and alpha searchers. Where the bot cannot do this (e.g. where the underlying data is
  # only available as a CSV file, it can be left as a stub method)
  def process_datum(datum_hash)
  end

end
