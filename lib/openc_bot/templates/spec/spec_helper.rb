require 'rspec/autorun'

RSpec.configure do |config|

end

# Utility method to allow sample html pages, csv files, json or whatever.
# Expects the files to be stored in a 'dummy_responses' folder in the spec directory
#
def dummy_response(response_name, options={})
  IO.read(File.join(File.dirname(__FILE__),"dummy_responses",response_name.to_s), options)
end

Mail.defaults do
  delivery_method :test # no, don't send emails when testing,
end