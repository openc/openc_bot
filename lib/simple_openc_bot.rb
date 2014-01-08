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

  # Override default in ScraperWiki gem
  def sqlite_magic_connection
    path = File.expand_path(File.join(File.dirname(__FILE__),'..'))
    db = @config ? @config[:db] : File.expand_path(File.join(path, 'db', db_name))
    @sqlite_magic_connection ||= SqliteMagic::Connection.new(db)
  end

  def update_data
    saves_by_class = {}
    fetch_records.each_slice(500) do |records|
      sqlite_magic_connection.execute("BEGIN TRANSACTION")
      records.each do |record|
        insert_or_update(record.class.unique_fields,
          record.to_hash)
        saves_by_class[record.class] ||= 0
        saves_by_class[record.class] += 1
        if saves_by_class[record.class] == 1
          check_unique_index(record.class)
        end
      end
      sqlite_magic_connection.execute("COMMIT")
    end
    if !saves_by_class.empty?
      # ensure there's a last_exported_date column
      sqlite_magic_connection.add_columns('ocdata', [:last_exported_date])
    end
    save_run_report(:status => 'success', :completed_at => Time.now)
  end

  def check_unique_index(record_class)
    indexes = sqlite_magic_connection.execute("PRAGMA INDEX_LIST('ocdata')")
    db_unique_fields = indexes.map do |i|
      next if i["unique"] != 1
      info = sqlite_magic_connection.execute("PRAGMA INDEX_INFO('#{i["name"]}')")
      info[0]["name"]
    end.compact
    record_unique_fields = record_class.unique_fields.map(&:to_s)
    if !(record_unique_fields - db_unique_fields).empty?
      sqlite_magic_connection.execute("ROLLBACK")
      error = "Unique fields #{record_unique_fields} are not unique indices in `ocdata` table!"
      error += "\nThis is usually because the value of unique_fields has changed since the table was automatically created."
      error += "\nUnique fields in `ocdata`: #{db_unique_fields}; in record #{record_class.name}: #{record_unique_fields}"
      raise error
    end
  end

  def count_stored_records
    sqlite_magic_connection.execute("select count(*) as count from ocdata").first["count"]
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
    select_records("ocdata.* from ocdata "\
                   "WHERE last_exported_date IS NULL "\
                   "OR last_exported_date < sample_date")
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
        updates[record.class.name] << record.to_hash.merge(:last_exported_date => Time.now.iso8601(2))
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
    total = count_stored_records
    selected = [opts[:limit], total].min
    puts "NOTICE: only validated first #{selected} of #{total} records"
    errors
  end


  class BaseLicenceRecord
    class_attribute :_store_fields, :_export_fields, :_unique_fields, :_type, :_schema

    def self.store_fields(*fields)
      self._store_fields ||= []
      self._store_fields.concat(fields)
      fields << :last_exported_date unless _store_fields.include?(:last_exported_date)
      fields.each do |field|
        attr_accessor field
      end
    end

    def self.unique_fields(*fields)
      self._unique_fields = fields unless fields.empty?
      self._unique_fields
    end

    def self.schema(schema)
      hyphenated_name = schema.to_s.gsub("_", "-")
      self._schema = File.expand_path("../../schemas/#{hyphenated_name}-schema.json", __FILE__)
    end

    def initialize(attrs={})
      if !_store_fields.include?(:sample_date)
        raise "Your record must define a sample_date field in store_fields"
      end
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
      if !self._schema
        # backwards compatibility
        self._schema = File.expand_path("../../schemas/licence-schema.json", __FILE__)
      end
      errors = JSON::Validator.fully_validate(
        self._schema,
        data.to_json,
        {:errors_as_objects => true})
      if !errors.empty?
        data[:errors] = errors
        data
      end
    end
  end
end
