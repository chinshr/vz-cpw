require "faraday"
require "spyke"
require "multi_json"

require "cpw/version"
require "cpw/store"
require "cpw/json_parser"
require "cpw/ingest"

require "pstore"

require "dotenv"
Dotenv.load

# Run: bundle exec irb -r "cpw"
module CPW
  store = Store.new

  puts ENV['CLIENT_KEY']
  puts store[:access_token]
  puts store[:access_secret]

  Spyke::Base.connection = Faraday.new(url: "http://localhost:3000/api/") do |c|
   c.request :json
   c.use CPW::JsonParser
   c.adapter Faraday.default_adapter
  end
end