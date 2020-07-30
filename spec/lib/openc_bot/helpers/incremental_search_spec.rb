# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/incremental_search"

module ModuleThatIncludesIncrementalSearch
  extend OpencBot
  extend OpencBot::Helpers::IncrementalSearch
  PRIMARY_KEY_NAME = :custom_uid
end

module ModuleWithNoCustomPrimaryKey
  extend OpencBot
  extend OpencBot::Helpers::IncrementalSearch
end

describe "a module that includes IncrementalSearch" do
  before do
    allow(ModuleThatIncludesIncrementalSearch).to receive(:sqlite_magic_connection).and_return(test_database_connection)
  end

  after do
    remove_test_database
  end

  it "has #increment_number method" do
    expect(ModuleThatIncludesIncrementalSearch).to respond_to(:increment_number)
  end

  describe "increment_number" do
    it "increases integer as number" do
      expect(ModuleThatIncludesIncrementalSearch.increment_number("234567")).to eq("234568")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("999")).to eq("1000")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("000123")).to eq("000124")
    end

    it "converts numbers to string" do
      expect(ModuleThatIncludesIncrementalSearch.increment_number(234_567)).to eq("234568")
    end

    it "increases number retaining any prefix" do
      expect(ModuleThatIncludesIncrementalSearch.increment_number("B123456")).to eq("B123457")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("B000456")).to eq("B000457")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("B-999")).to eq("B-1000")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("B-000999")).to eq("B-001000")
    end

    it "increases number retaining any suffix" do
      expect(ModuleThatIncludesIncrementalSearch.increment_number("123456B")).to eq("123457B")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("B000456B")).to eq("B000457B")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("999-B")).to eq("1000-B")
      expect(ModuleThatIncludesIncrementalSearch.increment_number("000999-B")).to eq("001000-B")
    end

    context "and number to increment given as option" do
      it "increments by given number" do
        expect(ModuleThatIncludesIncrementalSearch.increment_number("234567", 4)).to eq("234571")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("999", 4)).to eq("1003")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("000123", 4)).to eq("000127")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B123456", 3)).to eq("B123459")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B000456", 3)).to eq("B000459")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B-999", 4)).to eq("B-1003")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B-000999", 4)).to eq("B-001003")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("123456B", 3)).to eq("123459B")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B000456B", 3)).to eq("B000459B")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("999-B", 4)).to eq("1003-B")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("000999-B", 4)).to eq("001003-B")
      end
    end

    context "and negative number to increment given as option" do
      it "increments by given negative number i.e. it decreases" do
        expect(ModuleThatIncludesIncrementalSearch.increment_number("234567", -3)).to eq("234564")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("1002", -3)).to eq("999")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("000127", -3)).to eq("000124")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B123459", -3)).to eq("B123456")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B000459", -3)).to eq("B000456")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B-1003", -4)).to eq("B-999")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B-000999", -3)).to eq("B-000996")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("123459B", -3)).to eq("123456B")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("B000459B", -3)).to eq("B000456B")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("1003-B", -4)).to eq("999-B")
        expect(ModuleThatIncludesIncrementalSearch.increment_number("001003-B", -4)).to eq("000999-B")
      end
    end
  end

  it "has #incremental_search method" do
    expect(ModuleThatIncludesIncrementalSearch).to respond_to(:incremental_search)
  end

  describe "#incremental_search" do
    before do
      allow(ModuleThatIncludesIncrementalSearch).to receive(:create_new_company)
      allow(ModuleThatIncludesIncrementalSearch).to receive_messages(max_failed_count: 0)
    end

    it "iterates with prefixes, incrementing digits" do
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("12345", anything).and_return(:entry_1)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("12346", anything).and_return(:entry_2)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("12347", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("12348", anything)
      ModuleThatIncludesIncrementalSearch.incremental_search("12345")
    end

    it "uses increment_number to, er, increment number" do
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).and_return(:entry_1)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("25632", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:increment_number).with("12345").and_return("34567")
      expect(ModuleThatIncludesIncrementalSearch).to receive(:increment_number).with("34567").and_return("76543")
      expect(ModuleThatIncludesIncrementalSearch).to receive(:increment_number).with("76543").and_return("25632")
      ModuleThatIncludesIncrementalSearch.incremental_search("12345")
    end

    it "gets company details for given company number and subsequent company numbers until nil is returned more than max_failed_count times" do
      allow(ModuleThatIncludesIncrementalSearch).to receive_messages(max_failed_count: 2)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234568", anything).and_return(:entry_1)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234569", anything).and_return(:entry_2)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234570", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234571", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234572", anything).and_return(:entry_3)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234573", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234574", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234575", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("1234576", anything)
      ModuleThatIncludesIncrementalSearch.incremental_search("1234568")
    end

    it "returns last good number" do
      allow(ModuleThatIncludesIncrementalSearch).to receive_messages(max_failed_count: 2)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234568", anything).and_return(:entry_1)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234569", anything).and_return(:entry_2)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234570", anything).and_return(nil)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234571", anything).and_return(nil)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234572", anything).and_return(:entry_3)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234573", anything).and_return(nil)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234574", anything).and_return(nil)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234575", anything).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch.incremental_search("1234568")).to eq("1234572")
    end

    it "returns given number if no successful results" do
      allow(ModuleThatIncludesIncrementalSearch).to receive_messages(max_failed_count: 2)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).and_return(nil)
      expect(ModuleThatIncludesIncrementalSearch.incremental_search("1234568")).to eq("1234568")
    end

    context "and :skip_existing_entries passed in" do
      before do
        allow(ModuleThatIncludesIncrementalSearch).to receive(:datum_exists?).and_return(false)
        allow(ModuleThatIncludesIncrementalSearch).to receive(:datum_exists?).with("1234569").and_return(true)
        allow(ModuleThatIncludesIncrementalSearch).to receive(:datum_exists?).with("1234571").and_return(true)
      end

      it "does not update_datum for existing entries" do
        allow(ModuleThatIncludesIncrementalSearch).to receive_messages(max_failed_count: 2)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234568", anything).and_return(:entry_1)
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("1234569", anything)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234570", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("1234571", anything)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234572", anything).and_return(:entry_3)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234573", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234574", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234575", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("1234576", anything)
        ModuleThatIncludesIncrementalSearch.incremental_search("1234568", skip_existing_entries: true)
      end

      it "resets error count when existing entry found" do
        allow(ModuleThatIncludesIncrementalSearch).to receive_messages(max_failed_count: 1)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234568", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("1234569", anything)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234570", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("1234571", anything)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234572", anything).and_return(:entry_3)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234573", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("1234574", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("1234575", anything)
        ModuleThatIncludesIncrementalSearch.incremental_search("1234568", skip_existing_entries: true)
      end
    end

    context "and offset passed in as option" do
      it "gets entries beginning from given number adjusted by offset" do
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("12342", anything).and_return(:entry_1)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("12343", anything).and_return(:entry_2)
        expect(ModuleThatIncludesIncrementalSearch).to receive(:update_datum).with("12344", anything).and_return(nil)
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:update_datum).with("12345", anything)
        ModuleThatIncludesIncrementalSearch.incremental_search("12345", offset: -3)
      end
    end
  end

  describe "#incremental_rewind_count" do
    it "returns nil if INCREMENTAL_REWIND_COUNT not set" do
      expect(ModuleThatIncludesIncrementalSearch.send(:incremental_rewind_count)).to be_nil
    end

    it "returns value if INCREMENTAL_REWIND_COUNT set" do
      stub_const("ModuleThatIncludesIncrementalSearch::INCREMENTAL_REWIND_COUNT", 42)
      expect(ModuleThatIncludesIncrementalSearch.send(:incremental_rewind_count)).to eq(ModuleThatIncludesIncrementalSearch::INCREMENTAL_REWIND_COUNT)
    end
  end

  describe "#max_failed_count" do
    it "returns 0 if MAX_FAILED_COUNT not set" do
      expect(ModuleThatIncludesIncrementalSearch.send(:max_failed_count)).to eq(10)
    end

    it "returns value if MAX_FAILED_COUNT set" do
      stub_const("ModuleThatIncludesIncrementalSearch::MAX_FAILED_COUNT", 42)
      expect(ModuleThatIncludesIncrementalSearch.send(:max_failed_count)).to eq(ModuleThatIncludesIncrementalSearch::MAX_FAILED_COUNT)
    end
  end

  describe "entity_uid_prefixes" do
    context "and no ENTITY_UID_PREFIXES constant" do
      it "returns array containing nil" do
        expect(ModuleThatIncludesIncrementalSearch.entity_uid_prefixes).to eq([nil])
      end
    end

    context "and has ENTITY_UID_PREFIXES constant" do
      it "returns ENTITY_UID_PREFIXES" do
        stub_const("ModuleThatIncludesIncrementalSearch::ENTITY_UID_PREFIXES", %w[A X])
        expect(ModuleThatIncludesIncrementalSearch.entity_uid_prefixes).to eq(ModuleThatIncludesIncrementalSearch::ENTITY_UID_PREFIXES)
      end
    end
  end

  describe "entity_uid_suffixes" do
    context "and no ENTITY_UID_SUFFIXES constant" do
      it "returns array containing nil" do
        expect(ModuleThatIncludesIncrementalSearch.entity_uid_suffixes).to eq([nil])
      end
    end

    context "and has ENTITY_UID_SUFFIXES constant" do
      it "returns ENTITY_UID_SUFFIXES" do
        stub_const("ModuleThatIncludesIncrementalSearch::ENTITY_UID_SUFFIXES", %w[A X])
        expect(ModuleThatIncludesIncrementalSearch.entity_uid_suffixes).to eq(ModuleThatIncludesIncrementalSearch::ENTITY_UID_SUFFIXES)
      end
    end
  end

  describe "#fetch_data_via_incremental_search" do
    before do
      @most_recent_companies = %w[03456789 A12345]
      allow(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uids).and_return(@most_recent_companies)
      allow(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search)
    end

    it "finds highest_entry_uids" do
      expect(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uids)

      ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
    end

    context "and highest_entry_uids returns nil" do
      before do
        allow(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uids) #  => nil
      end

      it "does not do incremental_search" do
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:incremental_search)

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end

      it "does not update cached highest_entry_uid value" do
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:save_var)

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end
    end

    context "and highest_entry_uids returns values" do
      before do
        allow(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uids).and_return(@most_recent_companies)
      end

      it "does incremental_search starting at each highest company number" do
        expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("03456789", {})
        expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("A12345", {})

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end

      it "saves highest_entry_uids" do
        allow(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("03456789", anything).and_return("0345999")
        allow(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("A12345", anything).and_return("A234567")
        expect(ModuleThatIncludesIncrementalSearch).to receive(:save_var).with(:highest_entry_uids, %w[0345999 A234567])

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end

      context "and options passed to fetch_data_via_incremental_search" do
        it "passes them on to incremental search" do
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("03456789", foo: "bar")
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("A12345", foo: "bar")
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(foo: "bar")
        end
      end

      context "and library has incremental_rewind_count" do
        before do
          allow(ModuleThatIncludesIncrementalSearch).to receive(:incremental_rewind_count).and_return(42)
        end

        it "passes negated version on to incremental search as offset" do
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("03456789", hash_including(offset: -42))
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("A12345", hash_including(offset: -42))
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
        end

        it "asks to skip_existing_companies on incremental search by default" do
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("03456789", hash_including(skip_existing_entries: true))
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("A12345", hash_including(skip_existing_entries: true))
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
        end

        it "does not ask to skip_existing_companies on incremental search if requested not to" do
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("03456789", hash_including(skip_existing_entries: false))
          expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("A12345", hash_including(skip_existing_entries: false))
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(skip_existing_entries: false)
        end
      end
    end

    context "and highest_entry_uids passed in options" do
      it "does not find highest_entry_uids" do
        expect(ModuleThatIncludesIncrementalSearch).not_to receive(:highest_entry_uids)

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(highest_entry_uids: %w[1234 6543])
      end

      it "does incremental_search starting at provided highest company numbers" do
        expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("1234", {})
        expect(ModuleThatIncludesIncrementalSearch).to receive(:incremental_search).with("6543", {})

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(highest_entry_uids: %w[1234 6543])
      end
    end
  end

  describe "#highest_entry_uids" do
    before do
      allow(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).and_return("553311")
      allow(ModuleThatIncludesIncrementalSearch).to receive(:entity_uid_prefixes).and_return(%w[H P])
    end

    context "and highest_entry_uids not set in cache" do
      it "calls highest_entry_uid_result to get the highest value from the db for each prefix" do
        expect(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).with(prefix: "H").with(prefix: "P")
        ModuleThatIncludesIncrementalSearch.highest_entry_uids
      end

      it "returns highest uid" do
        expect(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).with(prefix: "H").and_return("H553311")
        expect(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).with(prefix: "P").and_return("P12345")
        expect(ModuleThatIncludesIncrementalSearch.highest_entry_uids).to eq(%w[H553311 P12345])
      end
    end

    context "and highest_entry_uid_result returns nil value" do
      before do
        allow(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).with(prefix: "H").and_return(nil)
        allow(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).with(prefix: "P").and_return("P12345")
      end

      it "returns only nil values" do
        expect(ModuleThatIncludesIncrementalSearch.highest_entry_uids).to eq(["P12345"])
      end
    end

    context "and highest_entry_uids in cache (saved var)" do
      before do
        @cached_result = "765432"
        ModuleThatIncludesIncrementalSearch.save_var("highest_entry_uids", @cached_result)
      end

      it "does not search for companies" do
        expect(ModuleThatIncludesIncrementalSearch).not_to receive("highest_entry_uid_result")
        ModuleThatIncludesIncrementalSearch.highest_entry_uids
      end

      it "returns cached highest_entry_uid" do
        expect(ModuleThatIncludesIncrementalSearch.highest_entry_uids).to eq(@cached_result)
      end

      context "and blank value returned for cached value" do
        before do
          ModuleThatIncludesIncrementalSearch.save_var("highest_entry_uids", ["H553311", ""])
        end

        it "ignores cached value" do
          expect(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).with(prefix: "H").with(prefix: "P")

          ModuleThatIncludesIncrementalSearch.highest_entry_uids
        end
      end

      context "and true passed in as argument" do
        before do
          ModuleThatIncludesIncrementalSearch.save_var("highest_entry_uids", %w[H553311 P1234])
        end

        it "ignores cached value" do
          expect(ModuleThatIncludesIncrementalSearch).to receive(:highest_entry_uid_result).with(prefix: "H").with(prefix: "P")

          ModuleThatIncludesIncrementalSearch.highest_entry_uids(true)
        end
      end
    end
  end

  describe "#highest_entry_uid_result" do
    context "in general" do
      before do
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "99999")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "5234888")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "9234567")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "A094567")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "A234567")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "SL34567")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "SL34999")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "H9999")
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "5234567")
      end

      context "and no options passed" do
        it "returns highest uid (primary key value) from the db" do
          expect(ModuleThatIncludesIncrementalSearch.highest_entry_uid_result).to eq("9234567")
        end
      end

      context "and prefix passed in options" do
        it "returns highest uid (numerically highest) which has the given prefix" do
          expect(ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(prefix: "A")).to eq("A234567")
          expect(ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(prefix: "SL")).to eq("SL34999")
        end
      end

      context "and suffix passed in options" do
        before do
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "009802V")
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "001234V")
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "34567C")
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "128055C")
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], custom_uid: "99999999")
        end

        it "returns highest uid (numerically highest) which has the given suffix" do
          expect(ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(suffix: "V")).to eq("009802V")
          expect(ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(suffix: "C")).to eq("128055C")
        end
      end
    end

    context "and no database created yet" do
      it "returns 0" do
        expect(ModuleThatIncludesIncrementalSearch.highest_entry_uid_result).to eq("0")
      end

      it "returns prefix plus 0 if prefix given" do
        expect(ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(prefix: "A")).to eq("A0")
      end
    end
  end
end
