require 'backports/2.0.0/enumerable/lazy'

module OpencBot
  class BaseIncrementer

    def initialize(opts={})
      @expected_count = opts[:expected_count]
      @count = 0
      @app_path = opts[:app_path]
      @show_progress = opts[:show_progress] || (opts[:show_progress].nil? && true)
    end

    def self.new(*args)
      path, = caller[0].partition(":")
      path = File.expand_path(File.join(File.dirname(path), ".."))
      args << {} if args.empty?
      args[0][:app_path] = path if !args[0][:app_path]
      super(*args)
    end

    def progress_percent
      (@count.to_f / @expected_count * 100).round(2) if @expected_count
    end

    def enum(opts={})
      enum = Enumerator.new do |yielder|
        increment_yielder do |result|
          write_current(result)
          yielder.yield(result)
          @count += 1
          puts "\nIterator progress: " + (progress_percent.to_s + "%") if @show_progress
        end
        reset_current
      end.lazy
      enum = resuming_enum(enum) unless opts[:reset_iterator]
      enum = enum.take(opts[:max_iterations]) if opts[:max_iterations]
      enum
    end

    def resuming_enum(enum)
      start_from = read_current
      found_start_point = false
      if start_from && start_from != ""
        enum = enum.drop_while do |x|
          found_start_point = (x.to_s == start_from)
          !found_start_point
        end
      end
      enum
    end

    def position_file_name
      "#{@app_path}/db/#{db_name}-iterator-position.txt"
    end

    def db_name
      self.class.name.split(':')[-1].downcase
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

    def populate(opts={})
      if !populated || opts[:reset_iterator]
        sqlite_magic_connection.execute("BEGIN TRANSACTION")
        yield(self)
        sqlite_magic_connection.execute("COMMIT")
      end
    end

    def initialize(opts={})
      @rows_count = 0
      super(opts)
    end

    # Override default in ScraperWiki gem
    def sqlite_magic_connection
      db = File.expand_path(File.join(@app_path, 'db', "#{db_name}.db"))
      @sqlite_magic_connection ||= SqliteMagic::Connection.new(db)
    end

    def increment_yielder(start_id=nil)
      @expected_count = count_items
      loop do
        result = read_batch(start_id).each do |row|
          yield row
          start_id = row['id']
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

    def save_hash(val)
      print "."
      save_sqlite([:id], val.merge({:id => @rows_count}), "items")
      @rows_count += 1
    end

    def count_items
      begin
        select("count(*) as count FROM items").first['count']
      rescue SqliteMagic::NoSuchTable
      end
    end

    def read_batch(start_id)
      sql = "* FROM items"
      if !start_id.nil?
        sql += " WHERE id > #{start_id}"
      end
      sql += " ORDER BY id LIMIT 100"
      select(sql)
    end

    # override superclass definition for more efficient version
    def resuming_enum(enum)
      current_id_match = read_current && read_current.match(/"id"=>(\d+)/)
      if current_id_match
        start_from = current_id_match[1].to_i
        @count = start_from
        enum = Enumerator.new do |yielder|
          increment_yielder(start_from) do |result|
            write_current(result)
            yielder.yield(result)
            @count += 1
          end
          reset_current
        end.lazy
      end
      enum
    end
  end
end
