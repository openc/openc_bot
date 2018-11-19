require "openc_bot"
require "openc_bot/company_fetcher_bot"
# We tend to use Nokogiri to parse HTML//XML but this is optional
require "nokogiri"
require "open-uri"

module XyCompaniesFetcher
  extend OpencBot
  # This adds the CompanyFetcherBot functionality
  extend OpencBot::CompanyFetcherBot

  module_function # make these methods as Module methods, rather than instance ones

  # The update_data module method is called when the bot is run. This is the only required method a bot needs,
  # and the only requirement that it needs to satisy is that it should save a company as a Hash that
  # conforms to the company-schema (https://github.com/openc/openc_bot/blob/master/schemas/company-schema.json)
  # using the #save_entity method. This method validates the hash, and saves in the database, adding the
  # ISO-3166-2 jurisdiction_code inferred from the name of the module (in this case xy)
  #
  # There are various helpers that we've found useful (see https://github.com/openc/openc_bot/tree/master/lib/openc_bot/helpers)
  # but not of them are required. For example, if you are doing an alpha search ('AA','AB',...) there are
  # intelligent defaults for doing such a search, and in fact you don't even need to write the #update_data
  # method. Similarly for incremental searches (where you are iterating through a series of increasing uids).
  # There are also helpers for normalising dates and text.
  def update_data
    # This code is actually for the Bermuda company register
    #
    # Get all the pages containing companies...
    a_z_links = Nokogiri.HTML(open("https://www.roc.gov.bm/roc/rocweb.nsf/ReviewPublicRegA-Z?OpenForm")).search("a")
    # iterate through them...
    a_z_links.each do |link|
      page = Nokogiri.HTML(open("https://www.roc.gov.bm" + link[:href]))
      # find all the companies in the table...
      page.search("//table[2]//tr").each do |tr|
        # extract the information
        name = begin
                 tr.at_xpath(".//td[2]//a").inner_text.strip
               rescue StandardError
                 nil
               end
        company_number = begin
                           tr.at("td a").inner_text.strip
                         rescue StandardError
                           nil
                         end
        incorporation_date = begin
                               tr.at(".//td[3]//a").inner_text.to_date.to_s
                             rescue StandardError
                               nil
                             end
        next if !name && !company_number && !incorporation_date

        # save the entity hash in the local database, using #save_entity helper method, which
        # validating it against the company schema first
        save_entity(name: name, company_number: company_number, incorporation_date: incorporation_date, retrieved_at: Time.now.to_s)
      end
    end
  end
end
