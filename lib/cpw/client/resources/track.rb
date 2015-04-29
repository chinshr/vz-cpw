module CPW
  module Client
    module Resources
      class Track < CPW::Client::Base
        uri "documents/(:document_id)/tracks/(:id)"
        include_root_in_json :track

        def s3_key
          s3_url ? s3_url.split("/").last : nil
        end
      end
    end
  end
end
