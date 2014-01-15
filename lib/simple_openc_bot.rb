require 'active_support/core_ext'
require 'openc_bot'
require 'json-schema'
require 'openc_bot/incrementer'

class SimpleOpencBot
  include OpencBot

  class_attribute :_yields

  def self.yields(*fields)
    raise "We currently only support one Record type per bot" if fields.count > 1
    self._yields = fields
  end

  def self.inherited(obj)
    path, = caller[0].partition(":")
    path = File.expand_path(File.join(File.dirname(path), ".."))
    @@simple_app_directory = path
  end

  # Override default in ScraperWiki gem
  def sqlite_magic_connection
    db = @config ? @config[:db] : File.expand_path(File.join(@@simple_app_directory, 'db', db_name))
    @sqlite_magic_connection ||= SqliteMagic::Connection.new(db)
  end

  def update_data(opts={})
    if opts[:specific_ids].empty?
      # fetch everything
      record_enumerator = Enumerator.new do |yielder|
        fetch_all_records(opts) do |result|
          yielder.yield(result)
        end
      end
    else
      # fetch records with specified ids
      record_enumerator = Enumerator.new do |yielder|
        fetch_specific_records(opts) do |result|
          yielder.yield(result)
        end
      end
    end
    saves_count = 0
    record_enumerator.each_slice(500) do |records|
      sqlite_magic_connection.execute("BEGIN TRANSACTION")
      records.each do |record|
        insert_or_update(record.class.unique_fields,
          record.to_hash)
        saves_count += 1
        if saves_count == 1
          check_unique_index(_yields[0])
        end
      end
      sqlite_magic_connection.execute("COMMIT")
    end
    if saves_count > 0
      # ensure there's internally-used columns
      sqlite_magic_connection.add_columns(
        'ocdata', [:_last_exported_at, :_last_updated_at])
    end
    save_run_report(:status => 'success', :completed_at => Time.now)
    saves_count
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

  def unexported_stored_records(opts={})
    sql = "ocdata.* from ocdata "\
      "WHERE (_last_exported_at IS NULL "\
      "OR _last_exported_at < _last_updated_at)"
    if !opts[:specific_ids].empty?
      ids = opts[:specific_ids].map{|id| "'#{id}'"}.join(",")
      sql += " AND #{_yields[0].unique_fields[0]} IN (#{ids})"
    end
    sql += " LIMIT #{opts[:batch]}" if opts[:batch]
    select_records(sql)
  end

  def spotcheck_records(limit = 5)
    select_records("ocdata.* from ocdata "\
                   "ORDER BY RANDOM()"\
                   "LIMIT #{limit}")
  end

  def select_records(sql)
    select(sql).map { |record| record['_type'].constantize.new(record) }
  end

  def export_data(opts={})
    Enumerator.new do |yielder|
      b = 1
      loop do
        batch = unexported_stored_records(:batch => 100, :specific_ids => opts[:specific_ids])
        break if batch.empty?
        updates = {}
        batch.map do |record|
          pipeline_data = record.to_pipeline
          updates[record.class.name] ||= []
          updates[record.class.name] << record.to_hash.merge(
            :_last_exported_at => Time.now.iso8601(2))
          yielder << pipeline_data
        end
        sqlite_magic_connection.execute("BEGIN TRANSACTION")
        updates.each do |k, v|
          save_data(k.constantize.unique_fields, v)
        end
        sqlite_magic_connection.execute("COMMIT")
        b += 1
      end
    end
  end

  def spotcheck_data
    batch = spotcheck_records
    batch.collect do |record|
      record.to_pipeline
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
    class_attribute :_store_fields, :_unique_fields, :_type, :_schema

    def self.store_fields(*fields)
      self._store_fields ||= []
      self._store_fields.concat(fields)
      fields << :_last_exported_at unless _store_fields.include?(:_last_exported_at)
      fields << :_last_updated_at unless _store_fields.include?(:_last_updated_at)
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
      validate_instance!
      attrs = attrs.with_indifferent_access
      self._type = self.class.name
      self._store_fields.each do |k|
        send("#{k}=", attrs[k])
      end
    end

    def validate_instance!
      all_errors = []
      required_functions = [:last_updated_at, :to_pipeline]
      func_errors = []
      required_functions.each do |func|
        if !respond_to?(func)
          func_errors << func
        end
      end
      if !func_errors.empty?
        all_errors << "You must define the following functions in your record class: #{func_errors.join(', ')}"
      end
      field_errors = []
      required_fields = [:_store_fields, :_unique_fields, :_schema]
      required_fields.each do |f|
        if !send(f)
          field_errors << f.to_s[1..-1]
        end
      end
      if !field_errors.empty?
        all_errors << "You must define the following fields on your record class: #{field_errors.join(', ')}"
      end
      raise all_errors.join('\n') unless all_errors.empty?
    end

    def to_hash
      hsh = Hash[_store_fields.map{|field| [field, send(field)]}]
      hsh[:_type] = self.class.name
      hsh[:_last_updated_at] = last_updated_at
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
