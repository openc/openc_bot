# encoding: UTF-8
require 'openc_bot/helpers/register_methods'

module OpencBot
  module Helpers
    module AlphaSearch

      include OpencBot::Helpers::RegisterMethods

      def alpha_terms(starting_term=nil)
        all_perms = letters_and_numbers.repeated_permutation(numbers_of_chars_in_search).
          collect(&:join)
        # get starting position from given term
        starting_position = starting_term && all_perms.index(starting_term)
        # start from starting_position if we have it or from start of array (pos 0) if not
        all_perms[starting_position.to_i..-1]
      end

      def fetch_data_via_alpha_search(options={})
        starting_term = options[:starting_term]||get_var('starting_term')
        each_search_term(starting_term) do |term|
          save_var('starting_term', term)
          search_for_entities_for_term(term, options) do |entity_datum|
            save_entity(entity_datum)
          end
        end
        # reset pointer
        save_var('starting_term',nil)
      end

      # Iterates through each search term, yielding the result to a block, or returning
      # the array of search_terms if no block given
      def each_search_term(starting_term=nil)
        alpha_terms(starting_term).each{ |t| yield t if block_given?}
      end

      def letters_and_numbers
        ('A'..'Z').to_a + ('0'..'9').to_a
      end

      def numbers_of_chars_in_search
        self.const_defined?('NUMBER_OF_CHARS_IN_SEARCH') ? self.const_get('NUMBER_OF_CHARS_IN_SEARCH') : 1
      end

      def search_for_entities_for_term(term, options={})
        raise "The #search_for_entities_for_term method has not been implemented for this case.\nIt needs to be, and should yield a company data Hash"
      end

      def get_results_and_extract_data_for(prefix, search_offset)
        while search_offset do
          url = "http://www.oera.li/WebServices/ZefixFL/ZefixFL.asmx/SearchFirm?name=#{prefix}%20&suche_nach=-&rf=&sitz=&id=&language=&phonetisch=no&posMin=#{search_offset}"
          response =
            begin
              html = open(url).read.encode!('utf-8','iso-8859-1')
            rescue Exception, Timeout::Error => e
              $stderr.puts "Problem getting/parsing data from #{url}: #{e.inspect}"
              nil
            end
          next unless response
          if response.match(/webservices\/HRG/) # check has links to companies
            $stderr.puts "****Scraping page #{(search_offset+10)/10}"
            scrape_search_results_page(response, url)
            save_var('search_offset', search_offset)
            search_offset += 10
          else
            search_offset = false
          end
        end
      end
    end

  end
end
