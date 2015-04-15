require "faraday"
require "spyke"
require "multi_json"

require "cpw/version"
require "cpw/json_parser"
require "cpw/ingest"

require "pstore"

require "dotenv"
Dotenv.load

# Run: bundle exec irb -r "cpw"
module CPW
  Store = PStore.new("cpw.pstore")

  Store.transaction do
    Store[:access_token] = "abcd1234"
  end
  puts ENV['CLIENT_KEY']

  Spyke::Base.connection = Faraday.new(url: "http://localhost:3000/api/") do |c|
   c.request :json
   c.use CPW::JsonParser
   c.adapter Faraday.default_adapter
  end
end