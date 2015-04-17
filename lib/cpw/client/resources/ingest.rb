module CPW
  module Client
    module Resource
      class Ingest < CPW::Client::Base
        uri "ingests/(:id)"
      end
    end
  end
end
