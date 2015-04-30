require "cpw/middleware/lock_ingest"

Shoryuken.configure_server do |config|
  config.server_middleware do |chain|
    chain.add ::CPW::Middleware::LockIngest
    # chain.remove MyMiddleware
    # chain.add MyMiddleware, foo: 1, bar: 2
    # chain.insert_before MyMiddleware, MyMiddlewareNew
    # chain.insert_after MyMiddleware, MyMiddlewareNew
  end
end