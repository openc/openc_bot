require "optparse"
require "json"
require "fileutils"

PRODUCTION_PID_DIR = "/oc/pids/external_bots".freeze

def pid_dir
  if Dir.exist?(PRODUCTION_PID_DIR)
    PRODUCTION_PID_DIR
  else
    pd = File.join(Dir.pwd, "pids")
    FileUtils.mkdir(pd) unless Dir.exist?(pd)
    pd
  end
end

namespace :bot do
  desc "create a skeleton bot that can be used in OpenCorporates"
  task :create do
    create_bot
  end

  desc "create a skeleton bot that can be used in OpenCorporates"
  task :create_company_bot do
    create_bot("company")
  end

  desc "Get data from target"
  task :run do |t, args|
    bot_name = get_bot_name
    begin
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
                  "Pass 'test' flag to bot") do |_val|
            options[:test_mode] = true
          end
          opts.on("-r", "--reset",
                  "Don't resume incremental bots; reset and start from the beginning") do |_val|
            options[:reset_iterator] = true
          end
          opts.on("-m", "--max-iterations MAX_ITERATIONS",
                  "Exit all iterators after MAX_ITERATIONS iterations. Useful for debugging.") do |val|
            options[:max_iterations] = val.to_i
          end
        end.parse!
        require_relative File.join(Dir.pwd, "lib", bot_name)
        runner = callable_from_file_name(bot_name)
        count = runner.update_data(options)
        puts "Got #{count} records"
      end
    rescue Exception => e
      raise e unless e.message[/already running/i]

      puts "Skipping running #{bot_name}: #{e.message}"
    end
  end

  desc "Get data from target"
  task :run2 do |_t, _args|
    bot_name = get_bot_name
    begin
      only_process_running("#{bot_name}-bot:run") do
        options = {}
        require_relative File.join(Dir.pwd, "lib", bot_name)
        runner = callable_from_file_name(bot_name)
        puts "Starting running #{bot_name} at #{Time.now}"
        runner.run
        puts "Finished running #{bot_name} at #{Time.now}"
      end
    rescue Exception => e
      raise e unless e.message[/already running/i]

      puts "Skipping running #{bot_name}: #{e.message}"
    end
  end

  desc "Update stale data from target"
  task :update_stale do
    only_process_running("update_stale") do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd, "lib", bot_name)
      runner = callable_from_file_name(bot_name)
      runner.update_stale
    end
  end

  desc "Run bot, but just for record with given uid"
  task :run_for_uid, :uid do |t, args|
    bot_name = get_bot_name
    only_process_running("#{bot_name}-#{t.name}-#{args[:uid]}") do
      require_relative File.join(Dir.pwd, "lib", bot_name)
      runner = callable_from_file_name(bot_name)
      # this should output the updated json data for the given uid to
      # STDOUT, as well as updating local database, when passed true as second argument
      runner.update_datum(args[:uid], true)
    end
  end

  desc "Unlock Sqlite db via backup"
  task :unlock_sqlite_db_via_backup do
    # see http://stackoverflow.com/questions/9449399/scheduling-a-rails-task-to-safely-backup-the-database-file?answertab=votes#tab-top
    bot_name = get_bot_name
    require_relative File.join(Dir.pwd, "lib", bot_name)
    runner = callable_from_file_name(bot_name)
    db_location = runner.db_location
    new_db_location = db_location + ".new"
    backup_db_location = db_location + ".bak"
    command = "sqlite3 #{db_location} '.backup #{new_db_location}'"
    puts `#{command}`
    FileUtils.mv db_location, backup_db_location
    FileUtils.mv new_db_location, db_location
    puts "Successfully recreated database via backup.\nNew db: #{db_location}\nOriginal db: #{backup_db_location}"
  end

  def klass_from_file_name(underscore_file_name)
    camelcase_version = underscore_file_name.split("_").map(&:capitalize).join
    Object.const_get(camelcase_version)
  end

  # At the moment, we have simple bots and bots; the former expect to
  # be instances, the latter modules with class methods.
  def callable_from_file_name(underscore_file_name)
    bot_klass = klass_from_file_name(underscore_file_name)
    callable = if bot_klass.respond_to?(:new)
                 bot_klass.new
               else
                 bot_klass
               end
    callable
  end

  def create_bot(template_name = "bot")
    working_dir = Dir.pwd
    bot_name = get_bot_name
    new_module_name = bot_name.split("_").collect(&:capitalize).join

    %w[bin db data lib spec spec/dummy_responses tmp pids].each do |new_dir|
      new_dir_path = File.join(working_dir, new_dir)
      FileUtils.mkdir_p(new_dir_path)
    end

    bot_template = "lib/#{template_name}.rb"
    templates = ["spec/spec_helper.rb", "spec/bot_spec.rb", "README.md", "config.yml", bot_template]
    templates.each do |template_location|
      template = File.open(File.join(File.dirname(__FILE__), "templates", template_location)).read
      template.gsub!("MyModule", new_module_name)
      template.gsub!("my_module", bot_name)
      new_file = File.join(working_dir, template_location.sub(/template/, "").sub(/bot/, bot_name).to_s)
      unless File.exist? new_file
        File.open(new_file, File::WRONLY | File::CREAT | File::EXCL) { |f| f.puts template }
        puts "Created #{new_file}"
      end
    end

    # Add rspec debugger to gemfile
    File.open(File.join(working_dir, "Gemfile"), "a") do |file|
      file.puts "group :test do\n  gem 'rspec'\n  gem 'debugger'\nend"
      puts "Added rspec and debugger to Gemfile at #{file}"
    end
    puts "Please run 'bundle install'"
  end

  def get_bot_name
    bot_name ||= Dir.pwd.split("/").last
  end

  def only_process_running(task_name)
    pid_path = File.join(pid_dir, task_name)

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
      raise "Already running #{pid_path}"
    end
  end

  def write_pid_file(pid_path)
    File.open(pid_path, "w") { |file| file.write(Process.pid) }
  end

  def remove_pid_file(pid_path)
    File.delete(pid_path) if File.exist?(pid_path)
  end
end
