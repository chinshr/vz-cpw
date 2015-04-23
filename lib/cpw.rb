require "faraday"
require "spyke"
require "multi_json"
require "pstore"
require "dotenv"
Dotenv.load

require "cpw/version"
require "cpw/store"
require "cpw/server"
require "cpw/worker"
require "cpw/worker/harvest"
require "cpw/worker/transcode"

require "cpw/client/json_parser"
require "cpw/client/adapter"
require "cpw/client/authorize"
require "cpw/client/base"

# Load resources
Dir[File.dirname(__FILE__) + "/cpw/client/resources/*.rb"].each {|file| require file}
Dir[File.dirname(__FILE__) + "/cpw/client/resources/**/*.rb"].each {|file| require file}

# Run: bundle exec irb -r "cpw"
module CPW
  include Client::Resources

  class << self
    attr_accessor :root_path
    attr_accessor :lib_path
    attr_accessor :store
    attr_accessor :base_url
    attr_accessor :client_key
    attr_accessor :device_uid
    attr_accessor :access_token
    attr_accessor :access_secret
    attr_accessor :user_email
    attr_accessor :user_password
  end

  self.root_path     = File.expand_path "../..", __FILE__
  self.lib_path      = File.expand_path "..", __FILE__
  self.base_url      = ENV['BASE_URL']
  self.client_key    = ENV['CLIENT_KEY']
  self.device_uid    = ENV['DEVICE_UID']
  self.user_email    = ENV['USER_EMAIL']
  self.user_password = ENV['USER_PASSWORD']
  self.store         = CPW::Store.new
  self.access_token  = store[:access_token]
  self.access_secret = store[:access_secret]

  puts ENV['BASE_URL']
  puts ENV['CLIENT_KEY']
  puts store[:access_token]
  puts store[:access_secret]

  Spyke::Base.connection = Faraday.new(url: ENV['BASE_URL']) do |c|
   c.request :json
   c.use CPW::JsonParser
   c.adapter Faraday.default_adapter  # CPW::Client::Adapter
   c.authorization "Token", :token => CPW::store[:access_token]
  end
end