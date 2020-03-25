require "openc_bot/version"
require "json"
require "scraperwiki"
require_relative "openc_bot/bot_data_validator"
require "openc_bot/helpers/text"
require "openc_bot/exceptions"
require "statsd-instrument"

module OpencBot
  class OpencBotError < StandardError; end
  class DatabaseError < OpencBotError; end
  class InvalidDataError < OpencBotError; end
  class NotFoundError < OpencBotError; end

  include ScraperWiki
  # include by default, as some were previously in made openc_bot file
  include Helpers::Text

  def insert_or_update(uniq_keys, values_hash, tbl_name = "ocdata")
    sqlite_magic_connection.insert_or_update(uniq_keys, values_hash, tbl_name)
  end

  def save_data(uniq_keys, values_array, tbl_name = "ocdata")
    save_sqlite(uniq_keys, values_array, tbl_name)
  end

  def save_run_report(report_hash)
    json_report = report_hash.to_json
    save_data([:run_at], { report: json_report, run_at: Time.now.to_s }, :ocrunreports)
  end

  # Returns the root directory of the bot (not this gem).
  # Assumes the bot file that extends its functionality using this bot is in a directory (lib) inside the root directory
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
end
