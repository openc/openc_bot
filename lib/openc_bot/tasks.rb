require 'simple_openc_bot'
require 'optparse'
require 'json'
require 'fileutils'

PID_DIR = "/oc/pids"

namespace :bot do
  desc "create a skeleton bot that can be used in OpenCorporates"
  task :create do
    create_bot
  end

  desc "create a skeleton bot that can be used in OpenCorporates"
  task :create_company_bot do
    create_bot('company')
  end

  desc "create a skeleton simple_bot that can be used in OpenCorporates"
  task :create_simple_bot do
    working_dir = Dir.pwd
    bot_name = get_bot_name
    new_module_name = bot_name.split('_').collect(&:capitalize).join
    %w(bin db data lib spec spec/dummy_responses tmp pids).each do |new_dir|
      Dir.mkdir(File.join(working_dir,new_dir)) unless Dir.exist?(File.join(working_dir,new_dir))
    end
    templates = ['spec/spec_helper.rb','spec/simple_bot_spec.rb','lib/simple_bot.rb', 'README.md', 'config.yml', 'bin/export_data', 'bin/fetch_data', 'bin/verify_data']
    templates.each do |template_location|
      template = File.open(File.join(File.dirname(__FILE__), 'templates',template_location)).read
      template.gsub!('MyLicence',new_module_name)
      template.gsub!('my_module',bot_name)
      begin
        new_file = File.join(working_dir,"#{template_location.sub(/template/,'').sub(/simple_bot/,bot_name)}")
        File.open(new_file,  File::WRONLY|File::CREAT|File::EXCL) { |f| f.puts template }
        $stderr.puts "Created #{new_file}"
      rescue Errno::EEXIST
        $stderr.puts "Skipped creating #{new_file} as it already exists"
      end
      FileUtils.chmod(0755, Dir.glob("#{working_dir}/bin/*"))
    end
    #Add rspec debugger to gemfile
    File.open(File.join(working_dir,'Gemfile'),'a') do |file|
      file.puts "group :test do\n  gem 'rspec'\n  gem 'debugger'\nend"
      $stderr.puts "Added rspec and debugger to Gemfile at #{file.path}"
    end
    $stderr.puts "Please run 'bundle install'"
  end

  desc 'Get data from target'
  task :run do |t, args|
    bot_name = get_bot_name
    only_process_running("#{bot_name}-#{t.name}") do
      options = {}
      options[:specific_ids] = []
      options[:reset_iterator] = false
      OptionParser.new(args) do |opts|
        opts.banner = "Usage: rake #{t.name} -- [options]"
        opts.on("-i", "--identifier UNIQUE_FIELD_VAL",
          "Identifier of specific record to fetch",
          " (may specify multiple times; refer to bot for its unique_fields)") do |val|
          options[:specific_ids] << val
        end
        opts.on("-t", "--test-mode",
          "Pass 'test' flag to bot") do |val|
          options[:test_mode] = true
        end
        opts.on("-r", "--reset",
          "Don't resume incremental bots; reset and start from the beginning") do |val|
          options[:reset_iterator] = true
        end
        opts.on("-m", "--max-iterations MAX_ITERATIONS",
          "Exit all iterators after MAX_ITERATIONS iterations. Useful for debugging.") do |val|
          options[:max_iterations] = val.to_i
        end
      end.parse!
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      count = runner.update_data(options)
      $stderr.puts "Got #{count} records"
    end
  end

  desc 'Update stale data from target'
  task :update_stale do
    only_process_running('update_stale') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      runner.update_stale
    end
  end

  desc 'Run bot, but just for record with given uid'
  task :run_for_uid, :uid do |t, args|
    bot_name = get_bot_name
    only_process_running(bot_name) do
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      # this should output the updated json data for the given uid to
      # STDOUT, as well as updating local database, when passed true as second argument
      runner.update_datum(args[:uid], true)
    end
  end

  desc 'Export data to stdout'
  task :export do |t, args|
    only_process_running(t.name) do
      options = {}
      options[:specific_ids] = []
      OptionParser.new(args) do |opts|
        opts.banner = "Usage: rake #{t.name} -- [options]"
        opts.on("-i", "--identifier UNIQUE_FIELD_VAL",
          "Identifier of specific record to export",
          " (may specify multiple times; refer to bot for its unique_fields)") do |val|
          options[:specific_ids] << val
        end
        opts.on("-a", "--all",
          "Export everything (default is only to export data that has changed since last export)") do |val|
          options[:all] = true
        end
      end.parse!
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      runner.export(options)
    end
  end

  desc 'Export 5 records to stdout for manual checking'
  task :spotcheck do
    only_process_running('spotcheck') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      runner.spotcheck
    end
  end

  desc 'Lists count of non-null values in each field in ocdata table'
  task :table_summary do
    only_process_running('table_summary') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      res = runner.table_summary
      res.each {|k,v| $stderr.puts "#{k}:\t#{v}"}
    end
  end

  desc 'Summarise data for quality checking (only works for licences at the moment)'
  task :summarise_data do
    def as_sorted_hash(name, data)
      title = "#{name} counts:"
      $stderr.puts title
      $stderr.puts "-" * title.length
      grouped = Hash[*data.group_by{|i| i}.map{|k,v| [Array(k).join(", "), v.count] }.flatten]
      hash = grouped.sort_by do |k, v|
        v
      end
      hash.each do |k, v|
        printf("%-60s %10s\n", k, v)
      end
      $stderr.puts
    end

    def as_longest_and_shortest(name, data)
      sorted = data.compact.sort_by do |n|
        n.length
      end
      $stderr.puts
      title = "shortest 5 #{name}"
      $stderr.puts title
      $stderr.puts "-" * title.length
      $stderr.puts sorted[0..5]
      $stderr.puts
      title = "longest 5 #{name}"
      $stderr.puts title
      $stderr.puts "-" * title.length
      $stderr.puts sorted[-5..-1]
      $stderr.puts
    end

    def main
      #result = open("foo", "r").read
      result = `bundle exec openc_bot rake bot:export -- -a`
      jurisdictions = []
      names = []
      start_dates = []
      end_dates = []
      sample_dates = []
      licence_numbers = []
      jurisdiction_classifications = []
      result.split(/\r?\n/).each do |line|
        line = JSON.parse(line)
        jurisdictions << line["company"]["jurisdiction"]
        names << line["company"]["name"]
        start_dates << line["start_date"]
        end_dates << line["end_date"]
        sample_dates << line["sample_date"]
        licence_numbers << line["data"][0]["properties"]["licence_number"]
        jurisdiction_classifications << line["data"][0]["properties"]["jurisdiction_classification"]
      end

      # This could be a histogram:
      as_sorted_hash("[company][jurisdiction]", jurisdictions)

      # This could be a list of the longest and shortest names:
      as_longest_and_shortest("[company][name]s", names)

      # earliest start date and latest start date and sample dates
      start_dates = start_dates.compact.sort
      end_dates = end_dates.compact.sort
      sample_dates = sample_dates.compact.sort
      $stderr.puts
      $stderr.puts "Dates"
      $stderr.puts "-----"
      printf("%-22s %10s\n", "Earliest start_date:", start_dates.first)
      printf("%-22s %10s\n", "Earliest end_date:", end_dates.first)
      printf("%-22s %10s\n", "Earliest sample_date:", end_dates.first)
      printf("%-22s %10s\n", "Latest start_date:", start_dates.last)
      printf("%-22s %10s\n", "Latest end_date:", end_dates.last)
      printf("%-22s %10s\n", "Latest sample_date:", sample_dates.last)

      as_longest_and_shortest("licence numbers", licence_numbers)
      as_sorted_hash("jurisdiction_classifications", jurisdiction_classifications)
    end

    main()

  end

  desc 'Lint old-style bots'
  task :lint do
    bot_name = get_bot_name
    require_relative File.join(Dir.pwd,'lib', bot_name)
    runner = callable_from_file_name(bot_name)
    messages = []
    if runner.method(:export_data).arity == 0
      messages <<  "export_data method must accept a hash as a single argument (e.g. `export_data(opts={})`"
    end

    if runner.is_a? SimpleOpencBot
      if !runner.respond_to? "fetch_all_records"
        messages <<  "You must rename fetch_records -> fetch_all_records."
      end

      full_source = File.open(File.join(Dir.pwd,'lib', bot_name) + ".rb").read
      if !full_source.match("^\s+yields")
        messages << <<EOF
You must call the `yields` class method with the class
of the Records you're returning. For example:

    class FooLicenses < SimpleOpencBot
        yields FooLicensesRecord

EOF
      end

      # fetch_all_methods must yield rather than return
      if runner.respond_to? "fetch_all_records"
        source, line = runner.method(:fetch_all_records).source_location
        count = 0
        found = false
        File.foreach(source, "\n") do |l|
          count += 1
          next if count < line + 1

          if l.match("^\s+yield")
            found = true
            break
          end
          break if l.match("^\s+def")
        end
        messages << "fetch_all_records must `yield` single records (rather than returning an array)" if !found
      end
    end
    messages.each_with_index do |m, i|
      $stderr.puts "#{i + 1}:"
      $stderr.puts m
      $stderr.puts "------------"
    end
    $stderr.puts "No problems!" if messages.empty?
  end

  task :test do
    bot_name = get_bot_name
    require_relative File.join(Dir.pwd,'lib', bot_name)
    runner = callable_from_file_name(bot_name)
    if runner.respond_to?(:validate_data)
      results = runner.validate_data
      if !results.empty?
        raise OpencBot::InvalidDataError.new(results)
      end
    else
      results = runner.export_data
      results.each do |datum|
        raise OpencBot::InvalidDataError.new("This datum is invalid: #{datum.inspect}") unless
          OpencBot::BotDataValidator.validate(datum)
      end
    end
    $stderr.puts "Congratulations! This data appears to be valid"
  end

  def klass_from_file_name(underscore_file_name)
    camelcase_version = underscore_file_name.split('_').map{ |e| e.capitalize }.join
    Object.const_get(camelcase_version)
  end

  # At the moment, we have simple bots and bots; the former expect to
  # be instances, the latter modules with class methods.
  def callable_from_file_name(underscore_file_name)
    bot_klass = klass_from_file_name(underscore_file_name)
    if bot_klass.respond_to?(:new)
      callable = bot_klass.new
    else
      callable = bot_klass
    end
    callable
  end

  def create_bot(template_name='bot')
    working_dir = Dir.pwd
    bot_name = get_bot_name
    new_module_name = bot_name.split('_').collect(&:capitalize).join

    %w(bin db data lib spec spec/dummy_responses tmp pids).each do |new_dir|
      new_dir_path = File.join(working_dir,new_dir)
      FileUtils.mkdir_p(new_dir_path)
    end

    bot_template = "lib/#{template_name}.rb"
    templates = ['spec/spec_helper.rb','spec/bot_spec.rb', 'README.md', 'config.yml', bot_template]
    templates.each do |template_location|
      template = File.open(File.join(File.dirname(__FILE__), 'templates',template_location)).read
      template.gsub!('MyModule',new_module_name)
      template.gsub!('my_module',bot_name)
      new_file = File.join(working_dir,"#{template_location.sub(/template/,'').sub(/bot/,bot_name)}")
      unless File.exists? new_file
        File.open(new_file,  File::WRONLY|File::CREAT|File::EXCL) { |f| f.puts template }
        $stderr.puts "Created #{new_file}"
      end
    end

    #Add rspec debugger to gemfile
    File.open(File.join(working_dir,'Gemfile'),'a') do |file|
      file.puts "group :test do\n  gem 'rspec'\n  gem 'debugger'\nend"
      $stderr.puts "Added rspec and debugger to Gemfile at #{file}"
    end
    $stderr.puts "Please run 'bundle install'"
  end

  def get_bot_name
    bot_name ||= Dir.pwd.split('/').last
  end

  def only_process_running(task_name)
    pid_path = Dir.exist?(PID_DIR) ? File.join(PID_DIR, 'pids', task_name) : File.join(Dir.pwd, 'pids', task_name)

    raise_if_already_running(pid_path)
    write_pid_file(pid_path)

    begin
      yield
    ensure
      remove_pid_file(pid_path)
    end
  end

  def raise_if_already_running(pid_path)
    begin
      pid = File.open(pid_path).read.to_i
    rescue Errno::ENOENT
      # PID file doesn't exist
      return
    end

    begin
      Process.getpgid(pid)
    rescue Errno::ESRCH
      # Process with PID doesn't exist
      # TODO Log this
      return
    else
      # Process with PID does exist
      # TODO Log this
      raise 'Already running'
    end
  end

  def write_pid_file(pid_path)
    File.open(pid_path, 'w') {|file| file.write(Process.pid)}
  end

  def remove_pid_file(pid_path)
    File.delete(pid_path)
  end

end
