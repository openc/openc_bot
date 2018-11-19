require_relative "../spec_helper"
require "openc_bot"
require_relative "../dummy_classes/foo_bot"

describe "A module that extends OpencBot" do
  before do
    @dummy_connection = double("database_connection")
    allow(FooBot).to receive(:sqlite_magic_connection).and_return(@dummy_connection)
  end

  it "includes ScraperWiki methods" do
    expect(FooBot).to respond_to(:save_sqlite)
  end

  it "defines OpencBotError exception as subclass of StandardError" do
    expect(OpencBot::OpencBotError.superclass).to be StandardError
  end

  it "defines DatabaseError exception as subclass of OpencBotError" do
    expect(OpencBot::DatabaseError.superclass).to be OpencBot::OpencBotError
  end

  it "defines InvalidDataError exception as subclass of OpencBotError" do
    expect(OpencBot::InvalidDataError.superclass).to be OpencBot::OpencBotError
  end

  describe "#insert_or_update" do
    before do
      @datum = { foo: "bar", foo2: "bar2", foo3: "bar3", foo4: "bar4" }
      @unique_keys = %i[foo2 foo3]
      @expected_query = "INSERT INTO foo_table (foo,foo2,foo3,foo4) VALUES (:foo,:foo2,:foo3,:foo4)"
    end

    it "delegates to connection" do
      expect(@dummy_connection).to receive(:insert_or_update).with(@unique_keys, @datum, "foo_table")
      FooBot.insert_or_update(@unique_keys, @datum, "foo_table")
    end

    it "uses ocdata table by default" do
      expect(@dummy_connection).to receive(:insert_or_update).with(@unique_keys, @datum, "ocdata")
      FooBot.insert_or_update(@unique_keys, @datum)
    end
  end

  describe "#unlock_database" do
    it "starts and end transaction on database" do
      expect(@dummy_connection).to receive(:execute).with("BEGIN TRANSACTION; END;")
      FooBot.unlock_database
    end
  end

  describe "#verbose?" do
    it 'returns false if ENV["VERBOSE"] not set' do
      expect(FooBot).not_to be_verbose
    end

    it 'returns true if ENV["VERBOSE"] set' do
      ENV["VERBOSE"] = "true"
      expect(FooBot).to be_verbose
      ENV["VERBOSE"] = nil # reset
    end
  end

  describe "#save_run_report" do
    it "save_datas in ocrunreports table" do
      expect(FooBot).to receive(:save_data).with(anything, anything, :ocrunreports)
      FooBot.save_run_report(foo: "bar")
    end

    it "converts run data into JSON" do
      dummy_time = Time.now
      allow(Time).to receive(:now).and_return(dummy_time)
      expected_run_report = { foo: "bar" }.to_json
      expect(FooBot).to receive(:save_data).with(anything, { report: expected_run_report, run_at: dummy_time.to_s }, anything)
      FooBot.save_run_report(foo: "bar")
    end

    it "uses timestamp as unique key" do
      expect(FooBot).to receive(:save_data).with([:run_at], anything, anything)
      FooBot.save_run_report(foo: "bar")
    end
  end

  describe "normalise_utf8_spaces private method" do
    it "converts UTF-8 spaces to normal spaces" do
      raw_and_normalised_text = {
        "Hello World" => "Hello World",
        "" => "",
        nil => nil,
        " \xC2\xA0\xC2\xA0 Mr Fred Flintstone  \xC2\xA0" => "    Mr Fred Flintstone   ",
      }
      raw_and_normalised_text.each do |raw_text, normalised_text|
        expect(FooBot.send(:normalise_utf8_spaces, raw_text)).to eq(normalised_text)
      end
    end
  end

  describe "#sqlite_magic_connection" do
    it "overrides default ScraperWiki#sqlite_magic_connection to use module name and adjacent db directory" do
      allow(FooBot).to receive(:sqlite_magic_connection).and_call_original
      expected_db_loc = File.expand_path(File.join(File.dirname(__FILE__), "..", "db", "foobot.db"))
      expect(SqliteMagic::Connection).to receive(:new).with(expected_db_loc, anything).and_return(@dummy_sqlite_magic_connection)
      FooBot.sqlite_magic_connection
    end

    it "sets busy_timeout to be 10000" do
      allow(FooBot).to receive(:sqlite_magic_connection).and_call_original
      expect(SqliteMagic::Connection).to receive(:new).with(anything, busy_timeout: 10_000).and_return(@dummy_sqlite_magic_connection)
      FooBot.sqlite_magic_connection
    end

    it "users SQLITE_BUSY_TIMEOUT if set" do
      allow(FooBot).to receive(:sqlite_magic_connection).and_call_original
      stub_const("FooBot::SQLITE_BUSY_TIMEOUT", 123)
      expect(SqliteMagic::Connection).to receive(:new).with(anything, busy_timeout: 123).and_return(@dummy_sqlite_magic_connection)
      FooBot.sqlite_magic_connection
    end
  end

  describe "#root_directory" do
    it "returns directory one up from that containing module" do
      expect(FooBot.root_directory).to eq(File.expand_path(File.join(File.dirname(__FILE__), "..")))
    end
  end

  describe "#data_dir" do
    it "returns data directory as a child of the root directory" do
      expect(FooBot.data_dir).to eq(File.expand_path(File.join(File.dirname(__FILE__), "..", "data")))
    end
  end
end
