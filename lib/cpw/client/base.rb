module CPW
  module Client
    class Base < Spyke::Base

      REQUEST_EXCEPTIONS = [
        Faraday::ClientError,
        Faraday::TimeoutError, Faraday::ConnectionFailed,
        Errno::ETIMEDOUT,
        Net::OpenTimeout, Net::ReadTimeout
      ]

      # Wrapper to retry requests N times before failing
      #
      # Client::Base::try_request do
      #   connection.get("foo/bar.json")
      # end
      #
      # Options:
      #
      #   `request_retries`: Number of retries
      #   `logger`: Logger instance
      #
      def self.try_request(options = {})
        request_retries = options[:request_retries] || CPW::request_retries
        request_delay_before_retry = options[:request_delay_before_retry] || CPW::request_delay_before_retry
        logger = options[:logger] || CPW::logger
        tried = 0
        begin
          tries_left ||= request_retries
          yield(tried, tries_left)
        rescue *REQUEST_EXCEPTIONS => ex
          tried += 1
          if (tries_left -= 1) > 0
            logger.debug "#{caller[1][/`.*'/][1..-2]} #{ex.message}, #{tried.ordinalize} try, #{tries_left} tries left"
            sleep (CPW::request_delay_before_retry || 3.0) + (rand(tried * 100) / 100.0)
            retry
          else
            raise ex
          end
        end
      end

      def present?
        !!self.try(:id)
      end

    end
  end
end