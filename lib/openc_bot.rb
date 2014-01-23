# encoding: UTF-8
require 'openc_bot/version'
require 'json'
require 'scraperwiki'
require_relative 'openc_bot/bot_data_validator'

module OpencBot

  class OpencBotError < StandardError;end
  class DatabaseError < OpencBotError;end
  class InvalidDataError < OpencBotError;end
  class NotFoundError < OpencBotError;end

  include ScraperWiki

  def insert_or_update(uniq_keys, values_hash, tbl_name='ocdata')
    sqlite_magic_connection.insert_or_update(uniq_keys, values_hash, tbl_name)
  end

  def save_data(uniq_keys, values_array, tbl_name='ocdata')
    save_sqlite(uniq_keys, values_array, tbl_name)
  end

  def save_run_report(report_hash)
    json_report = report_hash.to_json
    save_data([:run_at], { :report => json_report, :run_at => Time.now.to_s }, :ocrunreports)
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
    ENV['VERBOSE']
  end

  def export(opts={})
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
  def self.extended(obj)
    path, = caller[0].partition(":")
    path = File.expand_path(File.join(File.dirname(path),'..'))
    @@app_directory = path
  end

  def db_name
    if is_a?(Module)
      "#{self.name.downcase}.db"
    else
      "#{self.class.name.downcase}.db"
    end
  end

  # Override default in ScraperWiki gem
  def sqlite_magic_connection
    db = @config ? @config[:db] : File.expand_path(File.join(@@app_directory, 'db', db_name))
    @sqlite_magic_connection ||= SqliteMagic::Connection.new(db)
  end

  private
  # TODO: Move to helper class
  def normalise_utf8_spaces(raw_text)
    raw_text&&raw_text.gsub(/\xC2\xA0/, ' ')
    # raw_text&&raw_text.gsub(/&nbsp;|\xC2\xA0/, ' ')
  end

end
