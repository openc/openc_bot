require 'rspec'
require 'simple_openc_bot'

class LicenceRecord < SimpleOpencBot::BaseLicenceRecord
  JURISDICTION = "uk"
  store_fields :name, :type, :sample_date
  unique_fields :name

  URL = "http://foo.com"

  def jurisdiction_classification
    type
  end

  def to_pipeline
    {
      sample_date: "",
      company: {
        name: name,
        jurisdiction: JURISDICTION,
      },
      source_url: URL,
      data: [{
        data_type: :licence,
        properties: {
          category: 'Financial',
          jurisdiction_classification: [jurisdiction_classification],
        }
      }]
    }
  end

end

class TestLicenceBot < SimpleOpencBot

  def initialize(data={})
    @data = data
  end

  def fetch_records
    @data.map do |datum|
      LicenceRecord.new(datum)
    end
  end
end


describe LicenceRecord do
  before do
    @initial_values_hash = {:name => 'Foo',
                            :type => 'Bar'}

    @record = LicenceRecord.new(
      @initial_values_hash
    )
  end

  describe 'fields' do
    it 'has _type attribute' do
      @record._type.should == 'LicenceRecord'
    end

    it 'can get attribute' do
      @record.name.should == 'Foo'
    end

    it 'can set attribute' do
      @record.type = 'Baz'
      @record.type.should == 'Baz'
    end
  end

  describe "#to_hash" do
    it "should include all the specified fields as a hash" do
      @record.to_hash.should include(@initial_values_hash)
    end
  end
end

describe SimpleOpencBot do
  before do
  end

  after do
    table_names = %w(ocdata)
    table_names.each do |table_name|
      # flush table, but don't worry if it doesn't exist
      begin
        TestLicenceBot.new.sqlite_magic_connection.database.execute("DROP TABLE #{table_name}")
      rescue SQLite3::SQLException => e
        raise unless e.message.match(/no such table/)
      end
    end
  end


  describe ".update_data" do
    before do
      @properties = [
        {:name => 'Company 1', :type => 'Bank'},
        {:name => 'Company 2', :type => 'Insurer'}
      ]
      @bot = TestLicenceBot.new(@properties)
    end

    it "should call insert_or_update with correct unique fields" do
      @bot.stub(:check_unique_index)
      @bot.sqlite_magic_connection.stub(:add_columns)
      @bot.should_receive(:insert_or_update).with(
        LicenceRecord._unique_fields, anything).twice()
      @bot.update_data
    end

    it "should update rather than insert rows the second time" do
      @bot.update_data
      @bot.update_data
      @bot.count_stored_records.should == 2
    end

    it "should raise an error if the unique index has changed" do
      @bot.update_data
      LicenceRecord.stub(:unique_fields).and_return([:type])
      lambda do
        @bot.update_data
      end.should raise_error
    end

    it "should call insert_or_update with all records in a hash" do
      @bot.stub(:check_unique_index)
      @bot.sqlite_magic_connection.stub(:add_columns)
      @bot.should_receive(:insert_or_update).with(
        anything,
        hash_including(@properties.first))
      @bot.should_receive(:insert_or_update).with(
        anything,
        hash_including(@properties.last))
      @bot.update_data
    end
  end

  describe "export_data" do
    before do
      @properties = [
        {:name => 'Company 1', :type => 'Bank'},
        {:name => 'Company 2', :type => 'Insurer'}
      ]
      @bot = TestLicenceBot.new(@properties)
      @bot.update_data
    end

    it "should return all records the first time" do
      [*@bot.export_data].count.should == 2
    end

    it "should return records converted to pipeline format" do
      [*@bot.export_data][0][:company][:name].should == @properties[0][:name]
    end

    it "should set the last_exported_date on exported records" do
      [*@bot.export_data]
      @bot.all_stored_records.
        map(&:last_exported_date).compact.should_not be_nil
    end

    it "should not export data which has been exported before and for which the sample data has not changed" do
      [*@bot.export_data]
      [*@bot.export_data].count.should == 0
    end

    it "should export data which has been exported before and for which the sample data has changed" do
      results = [*@bot.export_data]
      sleep 0.5 # give sqlite a chance
      bot = TestLicenceBot.new([
        {:name => 'Company 1', :type => 'Bank'},
        {:name => 'Company 2', :type => 'Insurer', :sample_date => Time.now.iso8601(2)}])
      bot.update_data
      [*@bot.export_data].count.should == 1
    end
  end

  describe "stored data" do
    before do
      @properties = [
        {:name => 'Company 1', :type => 'Bank'},
        {:name => 'Company 2', :type => 'Insurer'}
      ]
      @bot = TestLicenceBot.new(@properties)
      @bot.update_data
    end

    describe "#all_stored_records" do
      it "should return an array of LicenceRecords" do
        @bot.all_stored_records.count.should == 2
        @bot.all_stored_records.map(&:class).uniq.should == [LicenceRecord]
      end
    end

    describe "#export_data" do
      it "should return an array of hashes" do
        result = @bot.export_data
        result.should be_a Enumerable
        result.count.should == @properties.count
      end

      it "should not re-export data twice" do
        @bot.export_data.count.should_not == 0
        @bot.export_data.count.should == 0
      end
    end

    describe "#validate_data" do
      before :each do
        SimpleOpencBot.any_instance.stub(:puts)
      end

      context "valid data" do
        it "should return empty array" do
          result = @bot.validate_data
          result.should be_empty
        end
      end

      context "invalid data" do
        it "should return an array of hashes with errors" do
          LicenceRecord.any_instance.stub(:to_pipeline).and_return({})
          result = @bot.validate_data
          result.count.should == 2
          result[0][:errors].should_not be_empty
        end
      end
    end
  end
end
