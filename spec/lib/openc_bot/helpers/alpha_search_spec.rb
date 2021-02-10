# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/alpha_search"

module ModuleThatIncludesAlphaSearch
  extend OpencBot
  extend OpencBot::Helpers::AlphaSearch
end

describe "a module that includes AlphaSearch" do
  before do
    allow(ModuleThatIncludesAlphaSearch).to receive(:sqlite_magic_connection)
      .and_return(test_database_connection)
  end

  after do
    remove_test_database
  end

  it "includes register_methods" do
    expect(ModuleThatIncludesAlphaSearch).to respond_to(:registry_url)
  end

  describe "#letters_and_numbers" do
    it "returns an array of all letters and numbers" do
      expect(ModuleThatIncludesAlphaSearch.letters_and_numbers).to eq(("A".."Z").to_a + ("0".."9").to_a)
    end
  end

  describe "numbers_of_chars_in_search" do
    context "and no NUMBER_OF_CHARS_IN_SEARCH constant" do
      it "returns 1" do
        expect(ModuleThatIncludesAlphaSearch.numbers_of_chars_in_search).to eq(1)
      end
    end

    context "and has NUMBER_OF_CHARS_IN_SEARCH constant" do
      it "returns NUMBER_OF_CHARS_IN_SEARCH" do
        stub_const("ModuleThatIncludesAlphaSearch::NUMBER_OF_CHARS_IN_SEARCH", 4)
        expect(ModuleThatIncludesAlphaSearch.numbers_of_chars_in_search).to eq(ModuleThatIncludesAlphaSearch::NUMBER_OF_CHARS_IN_SEARCH)
      end
    end
  end

  describe "#alpha_terms" do
    before do
      @letters_and_numbers = %w[A B 1 2]
      allow(ModuleThatIncludesAlphaSearch).to receive(:letters_and_numbers).and_return(@letters_and_numbers)
    end

    it "returns array of letters_and_numbers based on numbers_of_chars_in_search" do
      expect(ModuleThatIncludesAlphaSearch.alpha_terms).to eq(@letters_and_numbers)
      expect(ModuleThatIncludesAlphaSearch).to receive(:numbers_of_chars_in_search).and_return(2)
      expect(ModuleThatIncludesAlphaSearch.alpha_terms)
        .to eq(@letters_and_numbers.repeated_permutation(2).collect(&:join))
    end

    context "and starting character given" do
      it "starts array from given character" do
        expect(ModuleThatIncludesAlphaSearch.alpha_terms("B")).to eq(@letters_and_numbers[1..-1])
        allow(ModuleThatIncludesAlphaSearch).to receive(:numbers_of_chars_in_search).and_return(2)
        expect(ModuleThatIncludesAlphaSearch.alpha_terms("1B"))
          .to eq(%w[1B 11 12 2A 2B 21 22])
      end

      it "starts array from beginning if no such character" do
        expect(ModuleThatIncludesAlphaSearch.alpha_terms("X")).to eq(@letters_and_numbers)
        allow(ModuleThatIncludesAlphaSearch).to receive(:numbers_of_chars_in_search).and_return(2)
        expect(ModuleThatIncludesAlphaSearch.alpha_terms("C"))
          .to eq(@letters_and_numbers.repeated_permutation(2).collect(&:join))
      end
    end
  end

  describe "each_search_term" do
    before do
      allow(ModuleThatIncludesAlphaSearch).to receive(:alpha_terms).with("B").and_return(%w[C D])
    end

    it "iterates through alpha_terms and yield them" do
      yielded_data = []
      ModuleThatIncludesAlphaSearch.each_search_term("B") { |t| yielded_data << "#{t}#{t}" }
      expect(yielded_data).to eq(%w[CC DD])
    end

    context "and no block given" do
      it "returns alpha_terms" do
        expect(ModuleThatIncludesAlphaSearch.each_search_term("B")).to eq(%w[C D])
      end
    end
  end

  describe "#fetch_data_via_alpha_search" do
    before do
      @alpha_terms = %w[A1 B2 XX YY]
      allow(ModuleThatIncludesAlphaSearch).to receive(:create_new_company)
      allow(ModuleThatIncludesAlphaSearch).to receive(:save_entity)
      allow(ModuleThatIncludesAlphaSearch).to receive(:alpha_terms).and_return(@alpha_terms)
      allow(ModuleThatIncludesAlphaSearch).to receive(:search_for_entities_for_term).and_yield(nil)
    end

    it "search_for_entities_for_terms for each term in alpha_terms" do
      @alpha_terms.each do |term|
        expect(ModuleThatIncludesAlphaSearch).to receive(:search_for_entities_for_term).with(term, anything).and_yield(nil)
      end
      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
    end

    it "processes entity data yielded by search_for_entities_for_term" do
      @alpha_terms.each do |term|
        allow(ModuleThatIncludesAlphaSearch).to receive(:search_for_entities_for_term).with(term, anything).and_yield(:datum_one).and_yield(:datum_two)
      end
      expect(ModuleThatIncludesAlphaSearch).to receive(:save_entity).with(:datum_one)
      expect(ModuleThatIncludesAlphaSearch).to receive(:save_entity).with(:datum_two)

      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
    end

    it "starts from saved starting term" do
      ModuleThatIncludesAlphaSearch.save_var("starting_term", "B2")
      expect(ModuleThatIncludesAlphaSearch).to receive(:alpha_terms).with("B2").and_return(@alpha_terms)

      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
    end

    it "passes options to search_for_entities_for_term" do
      expect(ModuleThatIncludesAlphaSearch).to receive(:search_for_entities_for_term).with(anything, foo: "bar").and_yield(nil)

      ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search(foo: "bar")
    end

    context "and explicit starting_term passed in as option" do
      it "starts from given starting term" do
        ModuleThatIncludesAlphaSearch.save_var("starting_term", "B2")
        expect(ModuleThatIncludesAlphaSearch).to receive(:alpha_terms).with("XX").and_return(@alpha_terms)

        ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search(starting_term: "XX")
      end
    end

    context "and search gets to end of alpha_terms" do
      it "flushes starting_term record" do
        ModuleThatIncludesAlphaSearch.save_var("starting_term", "B2")

        ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search
        expect(ModuleThatIncludesAlphaSearch.get_var("starting_term")).to be_nil
      end
    end

    context "and search finishes before getting to end of alpha_terms" do
      it "stores term where it was working on where there was problem" do
        expect(ModuleThatIncludesAlphaSearch).to receive(:search_for_entities_for_term)
          .with(@alpha_terms.first, anything).and_yield(nil)

        expect(ModuleThatIncludesAlphaSearch).to receive(:search_for_entities_for_term)
          .with(@alpha_terms[1], anything).and_raise("Something has gone wrong")

        expect { ModuleThatIncludesAlphaSearch.fetch_data_via_alpha_search }.to raise_error(RuntimeError, "Something has gone wrong")
        expect(ModuleThatIncludesAlphaSearch.get_var("starting_term")).to eq(@alpha_terms[1])
      end
    end
  end

  describe "#search_for_entities_for_term" do
    it "raises exception" do
      expect { ModuleThatIncludesAlphaSearch.search_for_entities_for_term("foo") }.to raise_error(/method has not been implemented/)
    end
  end
end
