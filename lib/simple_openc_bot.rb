require 'active_support/core_ext'
require 'openc_bot'
require 'json-schema'

# This class converts a method which yields values into something that can be
# iterated over with `.each`.
class EnumeratorFromYielder
  include Enumerable

  def initialize(yielder)
    @yielder = yielder
  end

  def each
    @yielder.call {|item| yield item }
  end
end

class SimpleOpencBot
  include OpencBot

  def update_data
    fetch_records.each do |record|
      save_data(record.class.unique_fields, record.to_hash)
    end
  end

  def all_stored_records
    select_records("ocdata.* from ocdata")
  end

  def unexported_stored_records
    select_records("ocdata.* from ocdata WHERE last_exported_date IS NULL LIMIT 1000")
  end

  def select_records(sql)
    select(sql).map { |record| record['_type'].constantize.new(record) }
  end

  def export_data
    EnumeratorFromYielder.new(method(:yield_export_data))
  end

  def yield_export_data
    loop do
      batch = unexported_stored_records
      break if batch.empty?
      updates = {}
      batch.map do |record|
        updates[record.class.name] ||= []
        updates[record.class.name] << record.to_hash.merge(:last_exported_date => Time.now.to_i)
        yield record.to_pipeline
      end
      updates.each do |k, v|
        save_data(k.constantize.unique_fields, v)
      end
    end
  end

  def validate_data
    all_stored_records.map do |record|
      # first check they're JSON!
      errors = JSON::Validator.fully_validate(
        'pipeline-schema.json',
        record.to_pipeline,
        {:errors_as_objects => true, :validate_schema => true})
      #identifier = Hash[record.class.unique_fields.map{|field| [field, record.send(field)]}]
      identifier = JSON.parse(record.to_pipeline)
      if !errors.empty?
        identifier[:errors] = errors
        identifier
      end
    end.compact
  end

  def prepare_for_export(raw_data)
    record = Hash[raw_data.map {|k, v| [k.to_sym, v]}]
    company = record[:name]
    licence_property = {
      data_type: :licence,
      properties: {
        category: 'Financial',
        jurisdiction_classification: [record[:type]],
      }
    }
    output = {
      sample_date: record[:retrieved_at],
      company: {
        name: company_name,
        jurisdiction: JURISDICTION,
      },
      source_url: UTAH_INSTITUTIONS_FILE_URL,
      data: [licence_property],
      sample_date: record[:sample_date],
      end_date: record[:end_date]
    }
    # XXX all the other dates
    # XXX mark as exported
    output.to_json
  end

  def validate
    # check all_records has been implemented, and returns a list of BaseLicenceRecords
    # check final output against JSON schema
  end


  # def export_data
  #   sql_query = "ocdata.* from ocdata where seen_recently = 'yes'"
  #   select(sql_query).map do |record|
  #     company_record = Company.new(record)
  #     hash = prepare_for_export(company_record)

  #     last_retrieved_at = record[:retrieved_at]

  #     if DateTime.strptime(last_retrieved_at, '%Y-%m-%dT%H:%M:%S') < Time.now - 30.days
  #       hash[:end_date] = Time.now
  #       hash[:end_date_type] = 'before'
  #       record[:seen_recently] = 'no'
  #       save([record])
  #     else
  #       hash[:sample_date] = last_retrieved_at
  #     end


  #     hash
  #   end
  # end
#
#  def update_data
#    records = all_records.each {|record| record[:seen_recently] = 'yes'}
#    save(records)
#    save_run_report(:status => 'success')
#  end
#
#  private
#  def save(records)
#    unique_keys = records.first.unique_keys
#    data = records.map {|record| Hash[record]}
#    save_data(unique_keys, data)
#  end
#
#  def prepare_for_export(record)
#    raise 'Implement in bot'
#  end
#
#  def all_records
#    raise 'Implement in bot'
#  end
#
#  def unique_keys
#    raise 'Implement in bot'
#  end


  class BaseLicenceRecord
    class_attribute :_store_fields, :_export_fields, :_unique_fields, :_type

    def self.store_fields(*fields)
      self._store_fields = fields
      fields << :last_exported_date
      fields.each do |field|
        attr_accessor field
      end
    end

    def self.unique_fields(*fields)
      self._unique_fields = fields unless fields.empty?
      self._unique_fields
    end

    def initialize(attrs)
      attrs = attrs.with_indifferent_access
      self._type = self.class.name
      self._store_fields.each do |k|
        send("#{k}=", attrs[k])
      end
    end

    def to_hash
      hsh = Hash[_store_fields.map{|field| [field, send(field)]}]
      hsh[:_type] = self.class.name
      hsh
    end

    def mark_as_exported

    end

    def save
    end

  end
end
