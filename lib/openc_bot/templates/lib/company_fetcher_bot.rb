require "openc_bot"
require "openc_bot/company_fetcher_bot"

# you may need to require other libraries here
#
# require 'nokogiri'

# uncomment (and line further down) to get Date helper methods. (Also available csv and text helpers)
# require 'openc_bot/helpers/dates'

module MyModule
  extend OpencBot
  # This adds the CompanyFetcherBot functionality
  extend OpencBot::CompanyFetcherBot
  # uncomment to get Date helper methods
  # extend OpencBot::Helpers::Dates

  module_function # make these methods as Module methods, rather than instance ones

  # Uncomment to use alpha search – default is incremental search
  # USE_ALPHA_SEARCH = true

  # Default number of characters used for search terms in alpha search. Default is 1 (i.e. 'A','B'...)
  # NUMBER_OF_CHARS_IN_SEARCH = 3

  # If the register has a GET'able URL based on the company_number define it here. This should mean that
  # #fetch_datum 'just works'.
  def computed_registry_url(company_number)
    # e.g.
    # "http://some,register.com/path/to/#{company_number}"
  end

  # #fetch_data is the primary method for getting companies from the register, and by default is
  # called when the bot is 'run' (e.g. via bundle exec openc_bot rake bot:run, which calls
  # #update_data, which in turn calls this)
  # By default this uses an incremental search (which increments through :company_number identifiers),
  # or if USE_ALPHA_SEARCH has been set, an alpha search (e.g. searching for entities using 'AA', 'AB')
  # Define this locally if a different method for getting companies is going to done (e.g.
  # parsing a CSV file)
  # def fetch_data
  # end

  # This is called by #update_datum (defined in the IncrementalSearch helper module), which updates the
  # information for a given company_number. This allows the individual records to be updated, for example,
  # via the 'Update from Register' button on the company page on OpenCorporates. This method is also called
  # by the #fetch_data method in the case of incremental_searches.
  # By default it calls #fetch_registry_page with the company_number and returns the result in a hash,
  # with :company_page as a key. This will then be processed or parsed by the #process_datum method,
  # and the result will be saved by #update_datum, and also returned in a form that can be used by the
  # main OpenCorporates system
  #
  # This hash can contain other data, such as a page of filings or shareholdings. The hash will be
  # converted to json, and stored in the database in the row for that company number, under the
  # :data key, so that it can be reused or referred it in the future.
  # {:company_page => company_page_html, :filings_page => filings_page_html}
  # def fetch_datum(company_number)
  # end

  # This method must be defined for all bots that can fetch and process individual records, e.g.
  # incremental searchers, or individual company pages in an alpha search.
  # Where the bot cannot do this (e.g. where the underlying data is
  # only available as a CSV file, or there are no individual pages for each company, it can be
  # left as a stub method)
  # It should return a hash that conforms to the company-schema schema (and it will be checked)
  # against this schema before saving
  def process_datum(datum_hash)
    # write your code to parse what is in the company pages/data
  end

  # This is the standard method for alpha searches e.g. where you are searching a series of terms,
  # from A-Z0-9. You can increase the number of characters in the search term by setting the
  # NUMBER_OF_CHARS_IN_SEARCH constant (see above). Define this method locally if you need different
  # behavtiour o this
  # def fetch_data_via_alpha_search(options={})
  #   starting_term = options[:starting_term]||get_var('starting_term')
  #   each_search_term(starting_term) do |term|
  #     save_var('starting_term', term)
  #     search_for_entities_for_term(term, options) do |entity_datum|
  #       save_entity(entity_datum)
  #     end
  #   end
  #   # reset pointer
  #   save_var('starting_term',nil)
  # end

  # This method is called by #fetch_data_via_alpha_search (defined in AlphaSearch helper),
  # and is passed a search term, typically search term of a number of characters (e.g. 'AB', 'AC'...).
  # This method should yield a hash of company data which can be validated to the company-schema
  def search_for_entities_for_term(term, options = {})
    # write your code to search all the pages for the given term, and yield a series of company hashes
  end
end
