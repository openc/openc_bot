require 'retriable'
require 'httpclient'
class HTTPClient
   def get_content_with_retry(uri, *args, &block)
   log_info = Proc.new do |exception, tries|
     $stderr.puts( "HTTPClient retrying #{uri} because of #{exception.class}: '#{exception.message}' - #{tries} attempts." )
   end

   Retriable.retriable :on => [SystemCallError, SocketError, EOFError, HTTPClient::BadResponseError, HTTPClient::ReceiveTimeoutError, HTTPClient::ConnectTimeoutError, Errno::ETIMEDOUT],
     :tries => 10,
     :interval => 3,
     :on_retry => log_info do
       get_content( uri, *args, &block )
     end
  end

end

