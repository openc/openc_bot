# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'
require_relative '../dummy_classes/foo_bot'

describe "A module that extends OpencBot" do

  before do
    @dummy_connection = double('database_connection')
    FooBot.stub(:sqlite_magic_connection).and_return(@dummy_connection)
  end

  it "should include ScraperWiki methods" do
    FooBot.should respond_to(:save_sqlite)
  end

  it "should define OpencBotError exception as subclass of StandardError" do
    OpencBot::OpencBotError.superclass.should be StandardError
  end

  it "should define DatabaseError exception as subclass of OpencBotError" do
    OpencBot::DatabaseError.superclass.should be OpencBot::OpencBotError
  end

  it "should define InvalidDataError exception as subclass of OpencBotError" do
    OpencBot::InvalidDataError.superclass.should be OpencBot::OpencBotError
  end

  describe '#insert_or_update' do
    before do
      @datum = {:foo => 'bar', :foo2 => 'bar2', :foo3 => 'bar3', :foo4 => 'bar4'}
      @unique_keys = [:foo2,:foo3]
      @expected_query = "INSERT INTO foo_table (foo,foo2,foo3,foo4) VALUES (:foo,:foo2,:foo3,:foo4)"
    end

    it "should delegate to connection" do
      @dummy_connection.should_receive(:insert_or_update).with(@unique_keys, @datum, 'foo_table')
      FooBot.insert_or_update(@unique_keys, @datum, 'foo_table')
    end

    it "should use ocdata table by default" do
      @dummy_connection.should_receive(:insert_or_update).with(@unique_keys, @datum, 'ocdata')
      FooBot.insert_or_update(@unique_keys, @datum)
    end
  end

  describe '#unlock_database' do
    it "should start and end transaction on database" do
      @dummy_connection.should_receive(:execute).with('BEGIN TRANSACTION; END;')
      FooBot.unlock_database
    end
  end

  describe '#verbose?' do
    it 'should return false if ENV["VERBOSE"] not set' do
      FooBot.verbose?.should be_false
    end

    it 'should return false if ENV["VERBOSE"] set' do
      ENV["VERBOSE"] = 'true'
      FooBot.verbose?.should be_true
      ENV["VERBOSE"] = nil # reset
    end
  end

  describe '#save_run_report' do

    it 'should save_data in ocrunreports table' do
      FooBot.should_receive(:save_data).with(anything, anything, :ocrunreports)
      FooBot.save_run_report(:foo => 'bar')
    end

    it 'should convert run data into JSON' do
      dummy_time = Time.now
      Time.stub(:now).and_return(dummy_time)
      expected_run_report = ({ :foo => 'bar' }).to_json
      FooBot.should_receive(:save_data).with(anything, { :report => expected_run_report, :run_at => dummy_time.to_s }, anything)
      FooBot.save_run_report(:foo => 'bar')
    end

    it 'should use timestamp as unique key' do
      FooBot.should_receive(:save_data).with([:run_at], anything, anything)
      FooBot.save_run_report(:foo => 'bar')
    end
  end

  describe "normalise_utf8_spaces private method" do
    it "should convert UTF-8 spaces to normal spaces" do
      raw_and_normalised_text = {
        "Hello World" => "Hello World",
        '' => '',
        nil => nil,
        " \xC2\xA0\xC2\xA0 Mr Fred Flintstone  \xC2\xA0" => '    Mr Fred Flintstone   ',
                                  }
      raw_and_normalised_text.each do |raw_text, normalised_text|
        FooBot.send(:normalise_utf8_spaces, raw_text).should == normalised_text
      end
    end
  end

  describe "extract context from Nokogiri nodes" do
    before do
      @body = dummy_response('README.md')
    end

    it "should extract string from a single node" do
      FooBot.s_text(Nokogiri::HTML(@body).xpath(".//h1[a[@name='opencbot']]/text()")).should == "OpencBot"
      FooBot.s_text(Nokogiri::HTML(@body).xpath(".//h2[a[@name='overview']]/text()")).should == "Overview"
      FooBot.s_text(Nokogiri::HTML(@body).xpath(".//div[@class='flash flash-error']/text()")).should == "Something went wrong with that request. Please try again."
    end

    it "should extract to array of strings from a nodeset" do
      FooBot.a_text(Nokogiri::HTML(@body).xpath(".//h3[a[@name='break-it-into-stages']]/following-sibling::*[following-sibling::*[self::h4[a[@name='example-extract']]]]")).should == ["Think about breaking the scraping process down into three stages. This is sometimes referred to \nas \"Extract, Transform, Load\"", "\"Extract\" would mean saving the pages/data to the data folder. \"Transform\" means loading these files from the \ndata folder and parsing them into the right format (probably a hash). The final step, \"Load\", simply means saving them \nthe the database using the", "save_data", "method."]
    end
  end

  describe "#sqlite_magic_connection" do
    it "should override default ScraperWiki#sqlite_magic_connection to use module name and adjacent db directory" do
      FooBot.unstub(:sqlite_magic_connection)
      expected_db_loc = File.expand_path(File.join(File.dirname(__FILE__),'..','db','foobot.db'))
      SqliteMagic::Connection.should_receive(:new).with(expected_db_loc).and_return(@dummy_sqlite_magic_connection)
      FooBot.sqlite_magic_connection
    end
  end

  describe "#root_directory" do
    it "should return directory one up from that containing module" do
      FooBot.root_directory.should == File.expand_path(File.join(File.dirname(__FILE__), '..'))
    end
  end

end
