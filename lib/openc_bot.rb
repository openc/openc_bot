# frozen_string_literal: true

require "openc_bot/version"
require "json"
require "scraperwiki"
require_relative "openc_bot/bot_data_validator"
require_relative "openc_bot/bot_logger"
require "openc_bot/helpers/text"
require "openc_bot/jobs/single_record_update_job"
require "openc_bot/jobs/sru_request_job"
require "openc_bot/exceptions"
require "statsd-instrument"
require "aws-sdk-secretsmanager"
require "aws-sdk-s3"
require "zlib"

module OpencBot
  class OpencBotError < StandardError; end
  class DatabaseError < OpencBotError; end
  class InvalidDataError < OpencBotError; end
  class NotFoundError < OpencBotError; end

  include ScraperWiki
  # include by default, as some were previously in made openc_bot file
  include Helpers::Text

  LOGGER = BotLogger.instance

  attr_accessor :bot_run_id

  attr_accessor :bot_name

  def insert_or_update(uniq_keys, values_hash, tbl_name = "ocdata")
    sqlite_magic_connection.insert_or_update(uniq_keys, values_hash, tbl_name)
  end

  def aws_config_initialiser
    if ENV["AWS_PROFILE"]
      LOGGER.info({service: "openc_bot", event:"aws_config_initialiser", bot_name: bot_name, bot_run_id: bot_run_id, cred_type: "profile", aws_profile: ENV["AWS_PROFILE"]}.to_json)
      Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: ENV["AWS_PROFILE"])
    elsif ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
      LOGGER.info({service: "openc_bot", event:"aws_config_initialiser", bot_name: bot_name, bot_run_id: bot_run_id, cred_type: "access_key"}.to_json)
      Aws.config[:credentials] = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
    else
      LOGGER.warn({service: "openc_bot", event:"aws_config_initialiser", bot_name: bot_name, bot_run_id: bot_run_id, cred_type: nil, message:"credentials / profile not provided"}.to_json)
    end
    Aws.config[:region] = ENV["AWS_REGION"] || "eu-west-2"
  end

  def setup_s3_resource
    Aws::S3::Resource.new
  end

  def get_bot_secret(jurisdiction_code=nil, common_secret=nil)
    Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: 'bot')
    client = Aws::SecretsManager::Client.new(region: default_aws_region)
    if jurisdiction_code
      get_secret_value_response = client.get_secret_value(secret_id: "/external_bots/#{jurisdiction_code}_companies")
    else
      get_secret_value_response = client.get_secret_value(secret_id: "/external_bots/#{common_secret}_credentials")
    end
    # For a list of exceptions thrown, see
    # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
    secret = get_secret_value_response.secret_string
    JSON.parse(secret)
  rescue Exception => e
    send_error_report(e)
    raise e
  end

  def default_aws_region
    const_defined?("AWS_REGION") ? const_get("AWS_REGION") : "eu-west-2"
  end

  def upload_file_to_s3(bucket_name, output_file_location, input_file_location)
    aws_config_initialiser
    s3_client = setup_s3_resource
    LOGGER.info({service: "openc_bot", event:"upload_file_to_s3_begin", bot_name: bot_name, bot_run_id: bot_run_id, s3_bucket: bucket_name, s3_object: output_file_location, input_file: input_file_location}.to_json)
    begin
      start_time = Time.now
      file_name = output_file_location.match(/([^\/]+)$/)[1]
      file_extension = output_file_location.match(/\.(\w+)\.gz$/)[1]
      obj = s3_client.bucket(bucket_name).object(output_file_location)
      obj.put({body: File.read(input_file_location), tagging: "bot_name=#{bot_name}&file_name=#{file_name}&file_extension=#{file_extension}&bot_run_id=#{bot_run_id}"})
      LOGGER.info({service: "openc_bot", event:"upload_file_to_s3_end", ok:true, duration_s: (Time.now - start_time).round(2), bot_name: bot_name, bot_run_id: bot_run_id, s3_bucket: bucket_name, s3_object: output_file_location, input_file: input_file_location}.to_json)
    rescue Aws::S3::Errors::ServiceError => e
      LOGGER.error({service: "openc_bot", event:"upload_file_to_s3_error", ok:false, duration_s: (Time.now - start_time).round(2), bot_name: bot_name, bot_run_id: bot_run_id, s3_bucket: bucket_name, s3_object: output_file_location, input_file: input_file_location, message: e.message}.to_json)
      raise "#{e.message}"
    end
  end

  def save_data(uniq_keys, values_array, tbl_name = "ocdata")
    save_sqlite(uniq_keys, values_array, tbl_name)
  end

  def save_run_report(report_hash)
    json_report = report_hash.to_json
    save_data([:run_at], { report: json_report, run_at: Time.now.to_s }, :ocrunreports)
  end

  def data_dir
    File.join(root_directory, "data")
  end

  # Returns the root directory of the bot (not this gem).
  # Assumes the bot file that extends its functionality using this bot is in a directory (lib) inside the root directory
  def root_directory
    @@app_directory
  end

  def unlock_database
    sqlite_magic_connection.execute("BEGIN TRANSACTION; END;")
  end

  # Convenience method that returns true if VERBOSE environmental variable set (at the moment whatever it is set to)
  def verbose?
    ENV["VERBOSE"]
  end

  def export(opts = {})
    export_data(opts).each do |record|
      $stdout.puts record.to_json
      $stdout.flush
    end
  end

  def spotcheck
    $stdout.puts JSON.pretty_generate(spotcheck_data)
  end

  # When deciding on the location of the SQLite databases we need to
  # set the directory relative to the directory of the file/app that
  # includes the gem, not the gem itself.  Doing it this way, and
  # setting a class variable feels ugly, but this appears to be
  # difficult in Ruby, esp as the file may ultimately be called by
  # another process, e.g. the main OpenCorporates app or the console,
  # whose main directory is unrelated to where the databases are
  # stored (which means we can't use Dir.pwd etc). The only time we
  # know about the directory is when the module is called to extend
  # the file, and we capture that in the @app_directory class variable
  def self.extended(_obj)
    path, = caller[0].partition(":")
    path = File.expand_path(File.join(File.dirname(path), ".."))
    @@app_directory = path
  end

  def statsd_namespace
    @statsd_namespace ||= begin
      bot_env = ENV.fetch("FETCHER_BOT_ENV", "development").to_sym
      StatsD.mode = bot_env
      StatsD.server = "sys1:8125"
      StatsD.logger = Logger.new("/dev/null") if bot_env != :production

      if respond_to?(:inferred_jurisdiction_code) && inferred_jurisdiction_code
        "fetcher_bot.#{bot_env}.#{inferred_jurisdiction_code}"
      elsif is_a?(Module)
        "fetcher_bot.#{bot_env}.#{name.downcase}"
      else
        "fetcher_bot.#{bot_env}.#{self.class.name.downcase}"
      end
        .sub("companiesfetcher", "")
    end
  end

  def db_name
    if is_a?(Module)
      "#{name.downcase}.db"
    else
      "#{self.class.name.downcase}.db"
    end
  end

  def db_location
    File.expand_path(File.join(@@app_directory, "db", db_name))
  end

  # Override default in ScraperWiki gem
  def sqlite_magic_connection
    db = @config ? @config[:db] : File.expand_path(File.join(@@app_directory, "db", db_name))
    options = sqlite_busy_timeout ? { busy_timeout: sqlite_busy_timeout } : { busy_timeout: 10_000 }
    @sqlite_magic_connection ||= SqliteMagic::Connection.new(db, options)
  end

  def sqlite_busy_timeout
    const_defined?("SQLITE_BUSY_TIMEOUT") && const_get("SQLITE_BUSY_TIMEOUT")
  end

  def table_summary
    field_names = sqlite_magic_connection.execute("PRAGMA table_info(ocdata)").collect { |c| c["name"] }
    select_sql = "COUNT(1) Total, " + field_names.collect { |fn| "COUNT(#{fn}) #{fn}_not_null" }.join(", ") + " FROM ocdata"
    select(select_sql).first
  end

  # Compress the `input_file` to `output_file`
  # Currently this method is used to compress the output files
  # i.e. jsonl / db files before uploading to S3 bucket
  def compress_file(input_file, output_file)
    start_time = Time.now
    LOGGER.info({service: "openc_bot", event:"compress_file_begin", bot_name: bot_name, bot_run_id: bot_run_id, output_file: output_file.path, input_file: input_file}.to_json)
    Zlib::GzipWriter.open(output_file) do |gz|
      File.open(input_file, 'rb') do |file|
        IO.copy_stream(file, gz)
      end

      # This should be implicit, but added here just in case as there were issues with bad gz files being compressed.
      # Using IO.copy_stream should fix the root cause, but added this just in case.
      gz.close
    end
    LOGGER.info({service: "openc_bot", event:"compress_file_end", ok: true, duration_s: (Time.now - start_time).round(2), bot_name: bot_name, bot_run_id: bot_run_id, output_file: output_file.path, input_file: input_file}.to_json)
  end
end
