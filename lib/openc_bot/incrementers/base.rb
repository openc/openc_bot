require 'backports/2.0.0/enumerable/lazy'
require 'json'
module OpencBot
  class BaseIncrementer

    def initialize(name, opts={})
      @name = name
      @expected_count = opts[:expected_count]
      @count = 0
      @app_path = opts[:app_path]
      @show_progress = opts[:show_progress] || (opts[:show_progress].nil? && true)
      @reset_iterator = opts[:reset_iterator]
      @max_iterations = opts[:max_iterations]
      @opts = opts
    end

    def self.new(*args)
      path, = caller[0].partition(":")
      path = File.expand_path(File.join(File.dirname(path), ".."))
      args << {} if args.count == 1
      args[1][:app_path] = path if !args[1][:app_path]
      super(*args)
    end

    def log_progress(percent)
      puts "Iterator #{@name} progress: " + (percent.to_s + "%") if @show_progress
    end

    def progress_percent
      (@count.to_f / @expected_count * 100).round(2) if @expected_count
    end

    def each
      Enumerator.new do |yielder|
        increment_yielder do |result|
          if result.is_a? Hash
            formatted_result = result.to_json
          else
            formatted_result = result
          end
          write_current(formatted_result)
          yielder.yield(result)
          @count += 1
          log_progress(progress_percent)
        end
        reset_current
      end.lazy
    end

    def resumable
      enum = each
      enum = resuming_enum(enum) unless @reset_iterator
      enum = enum.take(@max_iterations) if @max_iterations
      enum
    end

    def resuming_enum(enum)
      start_from = read_current
      preset_show_progress = @show_progress
      @show_progress = false
      if start_from && start_from != ""
        enum = enum.drop_while do |x|
          found_start_point = (x.to_s == start_from)
          @show_progress = preset_show_progress && found_start_point
          !found_start_point
        end
      end
      enum
    end

    def position_file_name
      "#{@app_path}/db/#{db_name}-iterator-position.txt"
    end

    def db_name
      @name
    end

    # this is done with a file, rather than SQL, for speed reasons
    def reset_current
      File.open(position_file_name, "w") do |f|
        f.write("")
      end
    end

    def write_current(val)
      File.open(position_file_name, "w") do |f|
        f.write(val.to_s)
      end
    end

    def read_current
      begin
        File.open(position_file_name, "r") do |f|
          f.read
        end
      rescue Errno::ENOENT
        nil
      end
    end
  end

  class ManualIncrementer < OpencBot::BaseIncrementer

    include ScraperWiki

    ITEMS_TABLE = "items"

    def single_transaction
      sqlite_magic_connection.execute("BEGIN TRANSACTION")
      yield(self)
      sqlite_magic_connection.execute("COMMIT")
    end

    def initialize(name, opts={})
      super(name, opts)
      query = "CREATE TABLE IF NOT EXISTS #{ITEMS_TABLE} (#{opts[:fields].join(',')}, _id INTEGER PRIMARY KEY)"
      sqlite_magic_connection.execute query
      query = "CREATE UNIQUE INDEX IF NOT EXISTS #{opts[:fields].join('_')} " +
        "ON #{ITEMS_TABLE} (#{opts[:fields].join(',')})"
      sqlite_magic_connection.execute query
    end

    # Override default in ScraperWiki gem
    def sqlite_magic_connection
      db = File.expand_path(File.join(@app_path, 'db', "#{db_name}.db"))
      @sqlite_magic_connection ||= SqliteMagic::Connection.new(db)
    end

    def increment_yielder(start_row=nil)
      start_id = start_row && start_row["_id"].to_i
      @expected_count = count_all_items
      @count = count_processed_items(start_id)
      loop do
        result = read_batch(start_id).each do |row|
          yield row
          start_id = row["_id"].to_i + 1
        end
        raise StopIteration if result.empty?
      end
    end

    def populated
      begin
        result = select("populated FROM misc").first['populated']
        result && result == "true"
      rescue SqliteMagic::NoSuchTable
      end
    end

    def populated=(val)
      if val && val == "true" || val == true
        save_sqlite([], {:populated => "true"}, "misc")
      end
    end

    def enum(*args)
      self.populated = true
      super(enum(*args))
    end

    def add_row(val)
      sqlite_magic_connection.insert_or_update(
        val.keys, val, ITEMS_TABLE, :update_unique_keys => true)
    end

    def count_processed_items(start_id)
      if start_id
        begin
          result = select("count(*) as count FROM #{ITEMS_TABLE} WHERE _id < #{start_id}").first
          result && result['count']
        rescue SqliteMagic::NoSuchTable
          0
        end
      else
        0
      end
    end

    def count_all_items
      begin
        select("count(*) as count FROM #{ITEMS_TABLE}").first['count']
      rescue SqliteMagic::NoSuchTable
      end
    end

    def read_batch(start_id=nil)
      sql = "* FROM #{ITEMS_TABLE}"
      if start_id
        sql += " WHERE _id >= #{start_id}"
      end
      sql += " LIMIT 100"
      select(sql)
    end

    # override superclass definition for more efficient version
    def resuming_enum(enum)
      current_row = read_current && read_current != "" && JSON.parse(read_current)
      if current_row
        enum = Enumerator.new do |yielder|
          increment_yielder(current_row) do |result|
            write_current(result.to_json)
            yielder.yield(result)
            @count += 1
            log_progress(progress_percent)
          end
          reset_current
        end.lazy
      end
      enum
    end
  end
end
