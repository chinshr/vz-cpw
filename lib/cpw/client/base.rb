module CPW
  module Client
    class Base < Spyke::Base

        # Wrapper to retry requests N times before failing
        #
        # Client::Base::try_request do
        #   connection.get("foo/bar.json")
        # end
        def self.try_request(request_retries = nil)
          begin
            tries ||= (request_retries || CPW::request_retries)
            yield
          rescue Faraday::ClientError,
              Faraday::TimeoutError,
              Errno::ETIMEDOUT,
              Net::OpenTimeout,
              Faraday::ConnectionFailed => ex
            if (tries -= 1) > 0
              CPW::logger.debug "#{caller[1][/`.*'/][1..-2]} #{ex.message}, retries left #{tries}"
              sleep CPW::request_delay_before_retry
              retry
            else
              raise ex
            end
          end
        end

    end
  end
end