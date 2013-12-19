require 'rspec'
require 'simple_openc_bot'

class LicenceRecord < SimpleOpencBot::BaseLicenceRecord
  JURISDICTION = "uk"
  store_fields :name, :type
  unique_fields :name

  URL = "http://foo.com"

  def sample_date
    Time.now.iso8601(2)
  end

  def jurisdiction_classification
    type
  end

  def to_pipeline
    {
      sample_date: sample_date,
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
    }.to_json
  end

end

class TestLicenceBot < SimpleOpencBot
  def initialize(data={})
    @data = data
  end

  def fetch_records
    @data.map do |datum|
      LicenceRecord.new({
        :name => datum[:name],
        :type => datum[:type],
      })
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

  describe "#prepare_for_export" do
    it "should return fields in a hash as expected by license data_delegate" do
      puts @record.to_pipeline
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
      TestLicenceBot.new.sqlite_magic_connection.database.execute("DELETE FROM #{table_name}")
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

    it "should call save_data with correct unique fields" do
      @bot.should_receive(:save_data).with(
        LicenceRecord._unique_fields, anything).twice()
      @bot.update_data
    end

    it "should call save_data with all records in a hash" do
      @bot.should_receive(:save_data).with(
        anything,
        hash_including(@properties.first))
      @bot.should_receive(:save_data).with(
        anything,
        hash_including(@properties.last))
      @bot.update_data
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
        result.should be_a Array
        result.count.should == @properties.count
      end

      it "should not re-export data twice" do
        @bot.export_data.count.should_not == 0
        @bot.export_data.count.should == 0
      end
    end

    describe "#validate_data" do
      context "valid data" do
        it "should return empty array" do
          result = @bot.validate_data
          puts result
          result.should be_empty
        end
      end

      context "invalid data" do
        it "should return an array of hashes with errors" do
          LicenceRecord.any_instance.stub(:to_pipeline).and_return("{}")
          result = @bot.validate_data
          result.count.should == 2
          result[0][:errors].should_not be_empty
        end
      end
    end
  end
end
