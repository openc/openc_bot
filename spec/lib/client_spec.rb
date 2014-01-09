require 'rspec'
require 'openc_bot/client'

describe OpencBot::Client do
  it "should do stuff" do
    client = OpencBot::Client.new
    client.get("http://en.wikipedia.org/wiki/Texan")
  end
end
