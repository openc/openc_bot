# encoding: UTF-8
require 'openc_bot/version'
require 'json'
require 'scraperwiki'
require 'nokogiri'
require_relative 'openc_bot/bot_data_validator'

module OpencBot

  class OpencBotError < StandardError;end
  class DatabaseError < OpencBotError;end
  class InvalidDataError < OpencBotError;end

  include ScraperWiki

  # def default_database_file
  #   File.join(@@app_directory, '..','db', "#{self.name.downcase}.db")
  # end

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

  # def select_data(query_partial)
  #   raw_response = database.execute2('SELECT ' + query_partial)
  #   keys = raw_response.shift.map(&:to_sym) # get the keys
  #   raw_response.map{|e| Hash[keys.zip(e)] }
  # end

  def unlock_database
    sqlite_magic_connection.execute("BEGIN TRANSACTION; END;")
  end

  # Convenience method that returns true if VERBOSE environmental variable set (at the moment whatever it is set to)
  def verbose?
    ENV['VERBOSE']
  end

  # When deciding on the location of the SQLite databases we need to set the directory relative to the directory
  # of the file/app that includes the gem, not the gem itself.
  # Doing it this way, and setting a class variable feels ugly, but this appears to be difficult in Ruby, esp as the
  # file may ultimately be called by another process, e.g. the main OpenCorporates app or the console, whose main
  # directory is unrelated to where the databases are stored (which means we can't use Dir.pwd etc). The only time
  # we know about the directory is when the module is called to extend the file, and we capture that in the
  # @app_directory class variable
  def self.extended(obj)
    path, = caller[0].partition(":")
    @@app_directory = File.dirname(path)
  end

  # Override default in ScraperWiki gem
  def sqlite_magic_connection
    db = @config ? @config[:db] : File.expand_path(File.join(@@app_directory, '..','db', "#{self.name.downcase}.db"))
    @sqlite_magic_connection ||= SqliteMagic::Connection.new(db)
  end

  ## Extend method for extracting text from a single Nokogiri Node
  def s_text(node)
    return node.text.strip
  end

  ## Extend method for extracting text from a particular tree of Nokogiri Node(s)
  def a_text(node)
    ret = []
    if node.kind_of? (Nokogiri::XML::Element)
      tmp = []
      node.children().each{|nd|
        tmp << a_text(nd)
      }
      ret << tmp
    elsif node.kind_of? (Nokogiri::XML::NodeSet)
      node.collect().each{|nd|
        ret << a_text(nd)
      }
    elsif node.kind_of? (Nokogiri::XML::Text)
      ret << s_text(node)
    else
      raise "Invalid element found while processing innert text #{node}"
    end
    return ret.flatten
  end


  private
  def normalise_utf8_spaces(raw_text)
    raw_text&&raw_text.gsub(/\xC2\xA0/, ' ')
    # raw_text&&raw_text.gsub(/&nbsp;|\xC2\xA0/, ' ')
  end

end
