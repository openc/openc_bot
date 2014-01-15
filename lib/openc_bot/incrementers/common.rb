require 'openc_bot/incrementer'

module OpencBot
  class NumericIncrementer < OpencBot::Incrementer
    def initialize(opts={})
      raise "You must specify an end_val for a NumericIncrementer" if ! opts[:end_val]
      @start_val = opts[:start_val] || 0
      @end_val = opts[:end_val]
      super(opts)
    end

    def increment_yielder
      @expected_count = @end_val
      i = @start_val
      loop do
        if i > @end_val
          raise StopIteration
        end
        yield i
        i += 1
      end
    end
  end

  class AsciiIncrementer < OpencBot::Incrementer
    def increment_yielder
      @expected_count = 46656
      alnum = (0...36).map{|i|i.to_s 36} # 0...z
      all_perms = alnum.repeated_permutation(3)
      all_perms.each do |perm|
        yield perm.join
      end
    end
  end

  class ManualIncrementer < OpencBot::Incrementer

    include ScraperWiki

    def initialize(opts={})
      @rows_count = 0
      super(opts)
      sqlite_magic_connection.execute("BEGIN TRANSACTION")
    end

    # Override default in ScraperWiki gem
    def sqlite_magic_connection
      db = File.expand_path(File.join(@app_path, 'db', "#{db_name}.db"))
      @sqlite_magic_connection ||= SqliteMagic::Connection.new(db)
    end

    def enum(opts={})
      sqlite_magic_connection.execute("COMMIT")
      super(opts)
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

    def save_hash(val)
      save_sqlite([:id], val.merge({:id => @rows_count}), "items")
      @rows_count += 1
    end

    def count_items
      select("count(*) as count FROM items").first['count']
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
      current_id_match = read_current.match(/"id"=>(\d+)/)
      if current_id_match
        start_from = current_id_match[1].to_i
        enum = Enumerator.new do |yielder|
          increment_yielder(start_from) do |result|
            yielder.yield(result)
            @count += 1
            STDOUT.print(progress_percent.to_s + "\r") if @show_progress
          end
        end
      end
      enum
    end
  end
end
