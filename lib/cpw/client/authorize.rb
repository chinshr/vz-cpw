module CPW
  module Client
    class ClientError < StandardError
      attr_accessor :code, :http_status, :message

      def initialize(message = nil, code = nil, http_status = nil)
        @code        = code
        @message     = message
        @http_status = http_status
      end

      def inspect
        "code:#{code} message:#{message.to_s}"
      end
    end

    class AuthorizationError < ClientError
      def initialize(response)
        json         = JSON.parse(response.body)
        @code        = json['code']
        @message     = json['errors'].to_s
        @http_status = response.status
      end
    end

    module Authorize
      class << self
        def client!(client_key = CPW::client_key, device_uid = CPW::device_uid)
          Client::Base.try_request do
            response = connection.post("authorize/client.json", {client_key: client_key, device_uid: device_uid})
            body     = JSON.parse(response.body)

            if response.success? && body['code'] == 1
              CPW::store[:access_secret] = CPW::access_secret = body['access_secret']
              CPW::store[:access_token]  = CPW::access_token  = body['access_token']
              true
            else
              raise Client::AuthorizationError.new(response)
            end
          end
        end

        def user!(user_email = CPW::user_email, user_password = CPW::user_password, access_token = CPW::access_token)
          Client::Base.try_request do
            response = connection.post("authorize/user.json", {access_token: access_token, email: user_email, password: user_password})
            body = JSON.parse(response.body)
            if response.success? && body['code'] == 1
              true
            else
              raise Client::AuthorizationError.new(response)
            end
          end
        end

        def status(access_token = CPW::access_token)
          Client::Base.try_request do
            response = connection.get("authorize/status.json", {access_token: access_token})
            if response.success?
              JSON.parse(response.body)
            else
              raise Client::AuthorizationError.new(response)
            end
          end
        end

        def sign_out(access_token = CPW::access_token)
          Client::Base.try_request do
            response = connection.delete("authorize/user.json", {access_token: access_token})
            if response.success?
              true
            else
              raise Client::AuthorizationError.new(response)
            end
          end
        end

        def sign_in(user_email = CPW::user_email, user_password = CPW::user_password, access_token = CPW::access_token)
          json = status(access_token)
          if json['access_status'] == 0
            user!(user_email, user_password)
          end
        rescue Client::AuthorizationError => ex
          client! && user!(user_email, user_password)
        end

        def sign_out(access_token = CPW::access_token)
          response = connection.delete("authorize/user.json", {access_token: access_token})
          if response.success?
            true
          else
            raise Client::AuthorizationError.new(response)
          end
        end

        private

        def connection
          Faraday.new(url: CPW::base_url) do |c|
            c.headers['Content-Type'] = 'application/json'
            c.request :json
            c.response :logger
            c.adapter Faraday.default_adapter
            c.options.timeout      = CPW::connection_timeout
            c.options.open_timeout = CPW::connection_open_timeout
          end
        end

      end
    end
  end
end
