module CPW
  module Client
    class Adapter < ::Faraday::Middleware
      def call(env)
        env[:request_headers]['Authorization'] = CPW::store[:access_token]
        @app.call(env)
      end
    end
  end
end