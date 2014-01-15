require 'backports/2.0.0/enumerable/lazy'

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
          STDOUT.print(progress_percent.to_s + "\r") if @show_progress
        end
        reset_current
      end.lazy
      enum = resuming_enum(enum) unless opts[:reset]
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
end
