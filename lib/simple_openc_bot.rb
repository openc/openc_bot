require 'active_support/core_ext'
require 'openc_bot'
require 'json-schema'
require 'openc_bot/incrementers'

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
    if opts[:specific_ids].nil? || opts[:specific_ids].empty?
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
    batch_size = opts[:test_mode] ? 1 : 500
    record_enumerator.each_slice(batch_size) do |records|
      begin
        sqlite_magic_connection.execute("BEGIN TRANSACTION")
        records.each do |record|
          insert_or_update(record.class.unique_fields,
            record.to_hash)
          saves_count += 1
          if saves_count == 1
            # TODO: move this validation to somewhere more explicit
            raise "Bot must specify what record type it will yield" if _yields.nil?
            check_unique_index(_yields[0])
          end
          STDOUT.print(".")
          STDOUT.flush
        end
      ensure 
        sqlite_magic_connection.execute("COMMIT") if sqlite_magic_connection.database.transaction_active?
      end
    end
    save_run_report(:status => 'success', :completed_at => Time.now)
    saves_count
  end

  def check_unique_index(record_class)
    indexes = sqlite_magic_connection.execute("PRAGMA INDEX_LIST('ocdata')")
    db_unique_fields = indexes.map do |i|
      next if i["unique"] != 1
      next unless i["name"] =~ /autoindex/
      info = sqlite_magic_connection.execute("PRAGMA INDEX_INFO('#{i["name"]}')")
      info.map{|x| x["name"]}
    end.compact.flatten
    record_unique_fields = record_class.unique_fields.map(&:to_s)
    if db_unique_fields != record_unique_fields
      sqlite_magic_connection.execute("ROLLBACK")
      error = "Unique fields #{record_unique_fields} do not match the unique index(es) in `ocdata` table!"
      error += "\nThis is usually because the value of unique_field has changed since the table was automatically created."
      error += "\nUnique fields in `ocdata`: #{db_unique_fields.flatten}; in record #{record_class.name}: #{record_unique_fields}"
      raise error
    end
  end

  def count_stored_records
    begin
      all_stored_records(:count => true).first["count"]
    rescue SqliteMagic::NoSuchTable
      0
    end
  end

  def all_stored_records(opts={})
    if opts[:only_unexported]
      opts[:limit] ||= opts[:batch] 
    end

    select = opts[:select] || "ocdata.*"
    table = opts[:table] || "ocdata"
    where = (opts[:where] ?  "\nWHERE #{opts[:where]}\n" : "\nWHERE 1 \n")
    order = (opts[:order] ?  "\nORDER BY #{opts[:order]}\n" : "")
    limit = (opts[:limit] ? "\nLIMIT #{opts[:limit]}\n" : "")

    if opts[:only_unexported]
      where += " AND (_last_exported_at IS NULL "\
        "OR _last_exported_at < _last_updated_at)"

      if !opts[:specific_ids].blank?
        ids = opts[:specific_ids].map{|id| "'#{id}'"}.join(",")
        where += " AND #{_yields[0].unique_field} IN (#{ids})"
      end
    end

    if opts[:count]
      sql = "COUNT(*) AS count from #{table} #{where}"
      puts sql if opts[:debug]
      select(sql)
    else
      sql = "#{select} from #{table} #{where} #{order} #{limit}"
      puts sql if opts[:debug]
      select_records(sql)
    end
  end

  def unexported_stored_records(opts={})
    all_stored_records(opts.merge!(:only_unexported => true))
  end

  def spotcheck_records(limit = 5)
    all_stored_records(:order => "RANDOM()", :limit => limit)
  end

  def select_records(sql)
    select(sql).map { |record| record['_type'].constantize.new(record) }
  end

  def export_data(opts={})
    begin
      sqlite_magic_connection.add_columns(
        'ocdata', [:_last_exported_at, :_last_updated_at])
    rescue SQLite3::SQLException
    end
    Enumerator.new do |yielder|
      b = 1
      loop do
        if opts[:all]
          break if b > 1
          batch = all_stored_records(opts)
        else
          batch = unexported_stored_records(:batch => 100, :specific_ids => opts[:specific_ids])
        end
        break if batch.empty?
        updates = {}
        batch.map do |record|
          pipeline_data = record.to_pipeline
          next if pipeline_data.nil?
          updates[record.class.name] ||= []
          # opts[:all] is currently called in the bot:test rake task
          # This has the unfortunate side effect of updating the _last_exported_at
          # time when running the validation task, so I've added the following conditional
          if !opts[:all]
            updates[record.class.name] << record.to_hash.merge(
              :_last_exported_at => Time.now.iso8601(2))
          else
            updates[record.class.name] << record.to_hash
          end
          yielder << pipeline_data
        end
        sqlite_magic_connection.execute("BEGIN TRANSACTION")
        if b == 1
          check_unique_index(_yields[0])
        end
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
    class_attribute :_store_fields, :_type, :_schema, :_unique_fields

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
      if data
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
end
