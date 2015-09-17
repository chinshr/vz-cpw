require "fileutils"
require "faraday"
require "spyke"
require "multi_json"
require "pstore"
require "aws-sdk-v1"
require "mono_logger"
require "chronic"
require "dotenv"
Dotenv.load(*[".env.#{ENV.fetch("CPW_ENV", 'development')}", ".env"])

require "shoryuken"

require "cpw/version"
require "cpw/store"

require "cpw/client/json_parser"
require "cpw/client/adapter"
require "cpw/client/authorize"
require "cpw/client/base"
# Load client resources
Dir[File.dirname(__FILE__) + "/cpw/client/resources/*.rb"].each {|file| require file}
Dir[File.dirname(__FILE__) + "/cpw/client/resources/**/*.rb"].each {|file| require file}

require "pocketsphinx-ruby"
require "cpw/pocketsphinx/audio_file_speech_recognizer"

require "cpw/speech"

require "cpw/worker/base"
require "cpw/worker/helper"
require "cpw/middleware/lock_ingest"

require_relative "../config/initializers/shoryuken"

# Load workers
Dir[File.dirname(__FILE__) + "/cpw/worker/**/*.rb"].each {|file| require file}
CPW::Worker::Base.register_cpw_workers

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
    attr_accessor :logger

    def test?
      ENV['CPW_ENV'] == 'test'
    end

    def development?
      ENV['CPW_ENV'] == 'development'
    end

    def production?
      ENV['CPW_ENV'] == 'production'
    end
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
  self.logger        = MonoLogger.new(STDOUT)
  #self.logger.level  = MonoLogger::WARN

  logger.info "Loading #{ENV.fetch("CPW_ENV", 'development')} environment (CPW #{CPW::VERSION})"
  logger.info "Base URL: " + ENV.fetch('BASE_URL', 'unknown, missing BASE_URL in .env files')
  logger.info "Client key: " + ENV.fetch('CLIENT_KEY', 'unknown, missing CLIENT_KEY in .env files')
  logger.info "Access token: " + (store[:access_token] || "n/a in store")
  logger.info "Access secret: " + (store[:access_secret] || "n/a in store")

  Spyke::Base.connection = Faraday.new(url: ENV['BASE_URL']) do |c|
   c.request :json
   c.use CPW::JsonParser
   c.adapter Faraday.default_adapter  # CPW::Client::Adapter
   c.authorization "Token", :token => CPW::store[:access_token]
  end

  AWS.config(
    :access_key_id     => ENV['S3_KEY'],
    :secret_access_key => ENV['S3_SECRET']
  )
end