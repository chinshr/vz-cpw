module CPW
  class JsonParser < Faraday::Response::Middleware
    def parse(body)
      json = MultiJson.load(body, symbolize_keys: true)
      puts ">> :#{json.keys.reject {|k| [:code, :errors].include?(k)}.first}"
      {
        data: json[json.keys.reject {|k| [:code, :errors].include?(k)}.first || :data],
        metadata: json[:meta],
        errors: json[:errors]
      }
    rescue MultiJson::ParseError, TypeError => e
      {errors: {base: [error: e.message]}}
    end
  end
end