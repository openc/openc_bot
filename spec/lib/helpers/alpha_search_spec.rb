# encoding: UTF-8
require_relative '../../spec_helper'
require 'openc_bot'
require 'openc_bot/helpers/alpha_search'

module ModuleThatIncludesAlphaSearch
  extend OpencBot
  extend OpencBot::Helpers::AlphaSearch
end

describe 'a module that includes AlphaSearch' do

  before do
    ModuleThatIncludesAlphaSearch.stub(:sqlite_magic_connection).
                                  and_return(test_database_connection)
  end

  after do
    remove_test_database
  end

  it "should include register_methods" do
    ModuleThatIncludesAlphaSearch.should respond_to(:registry_url)
  end

  describe "#letters_and_numbers" do
    it "should return an array of all letters and numbers" do
      ModuleThatIncludesAlphaSearch.letters_and_numbers.should == ('A'..'Z').to_a + ('0'..'9').to_a
    end
  end

  describe "numbers_of_chars_in_search" do
    context 'and no NUMBER_OF_CHARS_IN_SEARCH constant' do
      it "should return 1" do
        ModuleThatIncludesAlphaSearch.numbers_of_chars_in_search.should == 1
      end
    end

    context 'and has NUMBER_OF_CHARS_IN_SEARCH constant' do
      it "should return NUMBER_OF_CHARS_IN_SEARCH" do
        stub_const("ModuleThatIncludesAlphaSearch::NUMBER_OF_CHARS_IN_SEARCH", 4)
        ModuleThatIncludesAlphaSearch.numbers_of_chars_in_search.should == ModuleThatIncludesAlphaSearch::NUMBER_OF_CHARS_IN_SEARCH
      end
    end
  end

  describe "#alpha_terms" do
    before do
      @letters_and_numbers = ['A','B','1','2']
      ModuleThatIncludesAlphaSearch.stub(:letters_and_numbers).and_return(@letters_and_numbers)
    end



    it "should return array of letters_and_numbers based on numbers_of_chars_in_search" do
      ModuleThatIncludesAlphaSearch.alpha_terms.should == @letters_and_numbers
      ModuleThatIncludesAlphaSearch.should_receive(:numbers_of_chars_in_search).and_return(2)
      ModuleThatIncludesAlphaSearch.alpha_terms.
        should == @letters_and_numbers.repeated_permutation(2).collect(&:join)
    end

    context "and starting character given" do
      it "should start array from given character" do
        ModuleThatIncludesAlphaSearch.alpha_terms('B').should == @letters_and_numbers[1..-1]
        ModuleThatIncludesAlphaSearch.stub(:numbers_of_chars_in_search).and_return(2)
        ModuleThatIncludesAlphaSearch.alpha_terms('1B').
          should == ["1B", "11", "12", "2A", "2B", "21", "22"]
      end
      it "should start array from beginning if no such character" do
        ModuleThatIncludesAlphaSearch.alpha_terms('X').should == @letters_and_numbers
        ModuleThatIncludesAlphaSearch.stub(:numbers_of_chars_in_search).and_return(2)
        ModuleThatIncludesAlphaSearch.alpha_terms('C').
          should == @letters_and_numbers.repeated_permutation(2).collect(&:join)
      end
    end
  end

  describe '#fetch_data_via_alpha_search' do
    before do
      @alpha_terms = ['A1','B2','XX','YY']
      ModuleThatIncludesAlphaSearch.stub(:create_new_company)
      ModuleThatIncludesAlphaSearch.stub(:process_datum)
      ModuleThatIncludesAlphaSearch.stub(:alpha_terms).and_return(@alpha_terms)
      ModuleThatIncludesAlphaSearch.stub(:search_for_entities_for_term).and_yield(nil)
    end

    it "should search_for_entities_for_term for each term in alpha_terms" do
      @alpha_terms.each do |term|
        ModuleThatIncludesAlphaSearch.should_receive(:search_for_entities_for_term).with(term, anything).and_yield(nil)
      end
      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
    end

    it "should prcess entity data yielded by search_for_entities_for_term" do
      @alpha_terms.each do |term|
        ModuleThatIncludesAlphaSearch.stub(:search_for_entities_for_term).with(term, anything).and_yield(:datum_1).and_yield(:datum_2)
      end
      ModuleThatIncludesAlphaSearch.should_receive(:process_datum).with(:datum_1)
      ModuleThatIncludesAlphaSearch.should_receive(:process_datum).with(:datum_2)

      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
    end

    it "should start from saved starting term" do
      ModuleThatIncludesAlphaSearch.save_var('starting_term', 'B2')
      ModuleThatIncludesAlphaSearch.should_receive(:alpha_terms).with('B2').and_return(@alpha_terms)

      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
    end

    it "should pass options to search_for_entities_for_term" do
      ModuleThatIncludesAlphaSearch.should_receive(:search_for_entities_for_term).with(anything, :foo => 'bar').and_yield(nil)

      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search(:foo => 'bar')
    end

    context "and explicit starting_term passed in as option" do
      it "should start from given starting term" do
        ModuleThatIncludesAlphaSearch.save_var('starting_term', 'B2')
        ModuleThatIncludesAlphaSearch.should_receive(:alpha_terms).with('XX').and_return(@alpha_terms)

        ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search(:starting_term => 'XX')
      end
    end

    context "and search gets to end of alpha_terms" do
      it "should flush starting_term record" do
        ModuleThatIncludesAlphaSearch.save_var('starting_term', 'B2')

        ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
        ModuleThatIncludesAlphaSearch.get_var('starting_term').should be_nil
      end
    end

    context "and search finishes before getting to end of alpha_terms" do
      it "should store term where it was working on where there was problem" do
        ModuleThatIncludesAlphaSearch.should_receive(:search_for_entities_for_term).
                                      with(@alpha_terms.first, anything).and_yield(nil)

        ModuleThatIncludesAlphaSearch.should_receive(:search_for_entities_for_term).
                                      with(@alpha_terms[1], anything).and_raise('Something has gone wrong')

        lambda { ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search }.should raise_error
        ModuleThatIncludesAlphaSearch.get_var('starting_term').should == @alpha_terms[1]
      end
    end
  end

  describe "#search_for_entities_for_term" do

    it "should raise exception" do
      lambda { ModuleThatIncludesAlphaSearch.search_for_entities_for_term('foo') }.should raise_error(/method has not been implemented/)
    end

  end

end