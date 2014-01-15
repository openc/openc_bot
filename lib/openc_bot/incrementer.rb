module OpencBot
  class Incrementer

    def initialize(opts={})
      @expected_count = opts[:expected_count]
      @count = 0
      @app_path = opts[:app_path]
      @show_progress = opts[:show_progress] || (opts[:show_progress].nil? && true)
    end

    def self.new(*args)
      path, = caller[0].partition(":")
      path = File.expand_path(File.join(File.dirname(path), ".."))
      args[0][:app_path] = path
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
          STDOUT.print(progress_percent.to_s + "\r") if @show_progress
        end
        reset_current
      end.lazy
      if opts[:restart]
        start_from = read_current
        if start_from && start_from != ""
          enum = enum.drop_while do |x|
            x.to_s != start_from
          end
        end
      end
      return enum
    end

    def persistence_file_name
      "#{@app_path}/db/#{self.class.name.split(':')[-1].downcase}-iterator-position.txt"
    end

    def reset_current
      File.open(persistence_file_name, "w") do |f|
        f.write("")
      end
    end

    def write_current(val)
      File.open(persistence_file_name, "w") do |f|
        f.write(val.to_s)
      end
    end

    def read_current
      begin
        File.open(persistence_file_name, "r") do |f|
          f.read
        end
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
