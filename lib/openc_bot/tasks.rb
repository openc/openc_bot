require 'simple_openc_bot'

namespace :bot do
  desc "create a skeleton bot that can be used in OpenCorporates"
  task :create do
    working_dir = Dir.pwd
    bot_name = get_bot_name
    new_module_name = bot_name.split('_').collect(&:capitalize).join
    %w(bin db data lib spec spec/dummy_responses tmp pids).each do |new_dir|
      Dir.mkdir(File.join(working_dir,new_dir)) unless Dir.exist?(File.join(working_dir,new_dir))
    end
    templates = ['spec/spec_helper.rb','spec/bot_spec.rb','lib/bot.rb', 'README.md', 'config.yml']
    templates.each do |template_location|
      template = File.open(File.join(File.dirname(__FILE__), 'templates',template_location)).read
      template.gsub!('MyModule',new_module_name)
      template.gsub!('my_module',bot_name)
      new_file = File.join(working_dir,"#{template_location.sub(/template/,'').sub(/bot/,bot_name)}")
      File.open(new_file,  File::WRONLY|File::CREAT|File::EXCL) { |f| f.puts template }
      puts "Created #{new_file}"
    end
    #Add rspec debugger to gemfile
    File.open(File.join(working_dir,'Gemfile'),'a') do |file|
      file.puts "group :test do\n  gem 'rspec'\n  gem 'debugger'\nend"
      puts "Added rspec and debugger to Gemfile at #{file}"
    end
    puts "Please run 'bundle install'"
  end

  desc "create a skeleton simple_bot that can be used in OpenCorporates"
  task :create_simple_bot do
    working_dir = Dir.pwd
    bot_name = get_bot_name
    new_module_name = bot_name.split('_').collect(&:capitalize).join
    %w(bin db data lib spec spec/dummy_responses tmp pids).each do |new_dir|
      Dir.mkdir(File.join(working_dir,new_dir)) unless Dir.exist?(File.join(working_dir,new_dir))
    end
    templates = ['spec/spec_helper.rb','spec/bot_spec.rb','lib/simple_bot.rb', 'README.md', 'config.yml', 'bin/export_data', 'bin/fetch_data', 'bin/verify_data']
    templates.each do |template_location|
      template = File.open(File.join(File.dirname(__FILE__), 'templates',template_location)).read
      template.gsub!('MyLicence',new_module_name)
      template.gsub!('my_module',bot_name)
      begin
        new_file = File.join(working_dir,"#{template_location.sub(/template/,'').sub(/simple_bot/,bot_name)}")
        File.open(new_file,  File::WRONLY|File::CREAT|File::EXCL) { |f| f.puts template }
        puts "Created #{new_file}"
      rescue Errno::EEXIST
        puts "Skpped created #{new_file} as it already exists"
      end
      FileUtils.chmod(0755, Dir.glob("#{working_dir}/bin/*"))
    end
    #Add rspec debugger to gemfile
    File.open(File.join(working_dir,'Gemfile'),'a') do |file|
      file.puts "group :test do\n  gem 'rspec'\n  gem 'debugger'\nend"
      puts "Added rspec and debugger to Gemfile at #{file}"
    end
    puts "Please run 'bundle install'"
  end

  desc 'Get data from target'
  task :run, :test_mode do |t, args|
    only_process_running('run') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      if runner.is_a?(SimpleOpencBot)
        runner.update_data(:test_mode => !!args[:test_mode])
        puts "Got #{runner.count_stored_records} records"
      else
        runner.update_data
      end
    end
  end

  desc 'Run bot, but just for record with given uid'
  task :run_for_uid, :uid do |t, args|
    only_process_running('run_for_uid') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      # this should output the updated json data for the given uid to
      # STDOUT, as well as updating local database, when passed true as second argument
      runner.update_datum(args[:uid], true)
    end
  end

  desc 'Export data to stdout'
  task :export do
    only_process_running('export') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      runner = callable_from_file_name(bot_name)
      runner.export
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
    puts "Congratulations! This data appears to be valid"
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

  def get_bot_name
    bot_name ||= Dir.pwd.split('/').last
  end

  def only_process_running(task_name)
    pid_path = File.join(Dir.pwd, 'pids', task_name)

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
