require 'rspec/autorun'
require 'debugger'

RSpec.configure do |config|
end

def remove_test_database
  File.delete(test_database_location) if File.exist?(test_database_location)
end

def test_database_location
  File.join(File.dirname(__FILE__),'db','test_db.db')
end

def test_database_connection
  @test_database_connection ||=SqliteMagic::Connection.new(test_database_location)
end
