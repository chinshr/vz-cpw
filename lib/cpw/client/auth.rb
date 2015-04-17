# Derived from https://github.com/mgomes/api_auth
# Net:HTTP cheat sheet: https://github.com/augustl/net-http-cheat-sheet
# Excon: https://github.com/geemus/excon
# Net HTTP cheat sheet: http://www.rubyinside.com/nethttp-cheat-sheet-2940.html
module CPW
  module Client
    module Auth
      class << self
        # Appends access_id and access_secret to a given request.
        #
        # Usage:
        #
        #     site     = "http://service.synctv.com/"
        #     uri      = URI.parse(site)
        #     http     = Net::HTTP.new(uri.host, uri.port)
        #     request  = Net::HTTP::Get.new("/api/v2/media.json",
        #       'content-type' => 'text/plain')
        #     access_id, access_secret = Synctv::Client::ApiAuth.authorize!
        #       site, "client_key", "device_uid", "account@email.com", "account_password"
        #     Synctv::Client::ApiAuth.append_signature!(request, access_id, access_secret)
        #     response = http.request(request)
        #
        def authorize!(site, client_key, device_uid = nil, account_email = nil, account_password = nil)
          access_id, access_secret = client_authorize!(site, client_key, device_uid)
          if account_email && account_password
            user_authorize!(site, access_id, access_secret, account_email, account_password)
          end
          return access_id, access_secret
        end

        def client_authorize!(client_key = CPW::client_key, device_uid = CPW::device_uid)
          connection = Faraday.new(url: CPW::base_url) do |c|
            c.request :json
            c.response :logger
            c.adapter Faraday.default_adapter
          end

          response = connection.post("authorize/client.json", {client_key: client_key, device_uid: device_uid})
          body = JSON.parse(response.body)
          puts body
          if body['code'] == 1
            CPW::store[:access_token]  = CPW::access_token  = body['access_token']
            CPW::store[:access_secret] = CPW::access_secret = body['access_secret']
          end
        end

        def user_authorize!(site, access_id, access_secret, account_email, account_password)
          http = Net::HTTP.new(site.host, site.port)
          if site.scheme == "https"
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          auth_request = Net::HTTP::Post.new("/api/v2/authorization/user/user_authorize.json?email=#{account_email}&password=#{account_password}&access_id=#{access_id}")
          path         = append_signature!(auth_request, access_id, access_secret)
          auth_request = Net::HTTP::Post.new(path)

          response = http.request(auth_request)

          if response.is_a?(Net::HTTPSuccess)
            true
          else
            raise "Could not authorize user."
          end
        end

      end # ClassMethods
    end # Auth
  end # Client
end # CPW