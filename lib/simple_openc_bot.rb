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

  def all_stored_records(opts={})
    if opts[:limit]
      sql = "ocdata.* from ocdata LIMIT #{opts[:limit]}"
    else
      sql = "ocdata.* from ocdata"
    end
    select_records(sql)
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

  def validate_data(opts={})
    opts = {:limit => 1000}.merge(opts)
    errors = all_stored_records(opts).map do |record|
      record.errors
    end.compact
    puts "NOTICE: only validated first #{opts[:limit]} records"
    errors
  end


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

    # return a structure including errors if invalid; otherwise return nil
    def errors
      data = self.to_pipeline
      errors = JSON::Validator.fully_validate(
        'schemas/licence-schema.json',
        data.to_json,
        {:errors_as_objects => true, :validate_schema => true})
      if !errors.empty?
        data[:errors] = errors
        data
      end
    end
  end
end
