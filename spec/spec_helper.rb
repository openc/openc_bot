# require 'rspec/autorun'
require "byebug"

RSpec.configure do |config|
end

def remove_test_database
  File.delete(test_database_location) if File.exist?(test_database_location)
end

def test_database_location
  db_dir = File.join(File.dirname(__FILE__), "db")
  Dir.mkdir(db_dir) unless Dir.exist?(db_dir)
  File.join(db_dir, "test_db.db")
end

def test_database_connection
  @test_database_connection ||= SqliteMagic::Connection.new(test_database_location)
end
