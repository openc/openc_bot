require 'active_support/cache'
require 'faraday_middleware'
require 'faraday_middleware/response_middleware'
require 'faraday_csv'
require 'faraday-http-cache'
begin
  require 'multi_xml'
rescue LoadError
  # pass
end

module OpencBot
  class Client
    def self.new(opts={})
      defaults = {:cache_dir => "webcachey", :expires_in => 86400}
      opts = defaults.merge(opts)
      Faraday.new do |conn|
        store = ActiveSupport::Cache::FileStore.new(
            opts[:cache_dir],
            :expires_in => opts[:expires_in])
        conn.use FaradayMiddleware::Caching, store, {}
        # encode request params as "www-form-urlencoded"
        conn.request :url_encoded
        # log request & response to STDOUT
        conn.response :raise_error
        conn.response :logger
        # Prob want always to pass the results through mechanize? *After* caching
        conn.adapter :httpclient
      end
    end
  end
end
