require "openssl"
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
require "byebug"

require "shoryuken"

require "cpw/version"
require "cpw/store"

require "cpw/client/json_parser"
require "cpw/client/adapter"
require "cpw/client/authorize"
require "cpw/client/base"

# Load app models
Dir[File.dirname(__FILE__) + "/../app/models/*.rb"].each {|file| require file}
Dir[File.dirname(__FILE__) + "/../app/models/**/*.rb"].each {|file| require file}

require "cpw/speech"

require "cpw/worker/base"
require "cpw/worker/helper"
require "cpw/middleware/lock_ingest"

require_relative "../config/initializers/shoryuken"

module CPW

  class << self
    attr_accessor :env
    attr_accessor :root_path
    attr_accessor :models_root_path
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
    attr_accessor :request_retries
    attr_accessor :connection_timeout
    attr_accessor :connection_open_timeout
    attr_accessor :request_delay_before_retry

    def test?
      env == 'test'
    end

    def development?
      env == 'development'
    end

    def production?
      env == 'production'
    end

    protected

    def register_workers
      Dir[File.dirname(__FILE__) + "/../app/workers/**/*.rb"].each do |file|
        begin
          require file
        rescue NameError => ex
          # TODO: autoload Ingest::MediaWorker module
          if module_name = ex.message.match(/^uninitialized constant (.*)/).try(:[], 1)
            eval "module ::#{module_name} end"
            require file
          else
            raise ex
          end
        end
      end
      CPW::Worker::Base.register_workers
    end

    def authorize
      return if CPW.test?
      sign_in_with_credentials unless sign_in_with_token
      logger.info "Authorization successful."
    end

    private

    def sign_in_with_credentials
      logger.info "Signing in with email: " + ENV.fetch('USER_EMAIL', 'unknown, missing USER_EMAIL in .env files')
      CPW::Client::Authorize.sign_in
    end

    def sign_in_with_token
      if access_token && access_secret
        logger.info "Signing in with access token: #{access_token || "<empty>"}"
        logger.info "And access secret: #{access_secret || "empty"}" if access_secret
        CPW::Client::Authorize.status
      end
    rescue Client::AuthorizationError
      false
    end

  end

  def with_warnings(flag)
    old_verbose, $VERBOSE = $VERBOSE, flag
    yield
  ensure
    $VERBOSE = old_verbose
  end

  def silence_warnings
    with_warnings(nil) { yield }
  end

  self.env              = ENV.fetch("CPW_ENV", 'development')
  self.root_path        = File.expand_path "../..", __FILE__
  self.models_root_path = File.join(File.expand_path("../../..", __FILE__), "vz-models")
  self.lib_path         = File.expand_path "..", __FILE__
  self.base_url         = ENV['BASE_URL']
  self.client_key       = ENV['CLIENT_KEY']
  self.device_uid       = ENV['DEVICE_UID']
  self.user_email         = ENV['USER_EMAIL']
  self.user_password      = ENV['USER_PASSWORD']
  self.store              = CPW::Store.new("cpw.#{self.env}.pstore")
  self.access_token       = store[:access_token]
  self.access_secret      = store[:access_secret]
  self.logger             = MonoLogger.new(STDOUT)

  self.request_retries            = ENV.fetch('REQUEST_RETRIES', 10).to_i
  self.request_delay_before_retry = ENV.fetch('REQUEST_DELAY_BEFORE_RETRY', 3).to_i
  self.connection_timeout         = ENV.fetch('CONNECTION_TIMEOUT', 5).to_i
  self.connection_open_timeout    = ENV.fetch('CONNECTION_OPEN_TIMEOUT', 5).to_i

  register_workers

  logger.info "Loading #{CPW.env} environment (CPW #{CPW::VERSION})"
  logger.info "Using API Base URL: " + ENV.fetch('BASE_URL', 'unknown, missing BASE_URL in .env files')
  logger.info "Client key: " + ENV.fetch('CLIENT_KEY', 'unknown, missing CLIENT_KEY in .env files')

  silence_warnings do
    OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  end

  authorize

  Spyke::Base.connection = Faraday.new(url: ENV['BASE_URL']) do |c|
    c.headers['Content-Type'] = 'application/json'
    c.request :json
    c.response :logger
    c.use CPW::JsonParser
    c.adapter Faraday.default_adapter  # CPW::Client::Adapter
    c.authorization "Token", :token => CPW::store[:access_token]
    c.options.timeout      = CPW::connection_timeout
    c.options.open_timeout = CPW::connection_open_timeout
  end

  AWS.config({
    access_key_id: ENV['S3_KEY'],
    secret_access_key: ENV['S3_SECRET']
  })
end
