require "cpw/middleware/lock_ingest"

Shoryuken.configure_server do |config|
  # @TODO AWS options not set through shoryuken.yml
  config.options[:aws][:access_key_id]     = ENV['S3_KEY']
  config.options[:aws][:secret_access_key] = ENV['S3_SECRET']
  config.options[:aws][:region]            = ENV['S3_AWS_REGION']

  config.server_middleware do |chain|
    chain.add ::CPW::Middleware::LockIngest
  end
end