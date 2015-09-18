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

module CPW
  include Client::Resources

  class << self
    attr_accessor :env
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
    attr_accessor :queue_name_mask
    attr_accessor :logger

    def test?
      env == 'test'
    end

    def development?
      env == 'development'
    end

    def production?
      env == 'production'
    end

    def load_workers!
      # Load workers
      Dir[File.dirname(__FILE__) + "/cpw/worker/**/*.rb"].each {|file| require file}
      CPW::Worker::Base.register_cpw_workers
    end
  end

  self.env             = ENV.fetch("CPW_ENV", 'development')
  self.root_path       = File.expand_path "../..", __FILE__
  self.lib_path        = File.expand_path "..", __FILE__
  self.base_url        = ENV['BASE_URL']
  self.client_key      = ENV['CLIENT_KEY']
  self.device_uid      = ENV['DEVICE_UID']
  self.user_email      = ENV['USER_EMAIL']
  self.user_password   = ENV['USER_PASSWORD']
  self.queue_name_mask = ENV.fetch('QUEUE_NAME_MASK', "%{stage}_%{env}_QUEUE")
  self.store           = CPW::Store.new("cpw.#{self.env}.pstore")
  self.access_token    = store[:access_token]
  self.access_secret   = store[:access_secret]
  self.logger          = MonoLogger.new(STDOUT)

  self.load_workers!

  logger.info "Loading #{CPW.env} environment (CPW #{CPW::VERSION})"
  logger.info "Using API Base URL: " + ENV.fetch('BASE_URL', 'unknown, missing BASE_URL in .env files')
  logger.info "Client key: " + ENV.fetch('CLIENT_KEY', 'unknown, missing CLIENT_KEY in .env files')
  if store[:access_token] && store[:access_secret]
    logger.info "Signing in with access token: " + (store[:access_token] || "n/a in store")
    logger.info "Access secret: " + (store[:access_secret] || "n/a in store")
  else
    logger.info "Signing in with email: " + ENV.fetch('USER_EMAIL', 'unknown, missing USER_EMAIL in .env files')
  end

  Spyke::Base.connection = Faraday.new(url: ENV['BASE_URL']) do |c|
   c.request :json
   c.use CPW::JsonParser
   c.adapter Faraday.default_adapter  # CPW::Client::Adapter
   c.authorization "Token", :token => CPW::store[:access_token]
  end

  AWS.config(
    access_key_id: ENV['S3_KEY'],
    secret_access_key: ENV['S3_SECRET']
  )
end