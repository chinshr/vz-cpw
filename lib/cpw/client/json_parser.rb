module CPW
  class JsonParser < Faraday::Response::Middleware
    def parse(body)
      json     = MultiJson.load(body, symbolize_keys: true)
      data     = json[json.keys.reject {|k| [:code, :errors].include?(k)}.first || :data] || {}
      metadata = json[:meta] || {}
      # {errors: { status: ["Event..."] }} -> {errors: { status: [{ error: 'Event...' }] }}
      errors   = (json[:errors] || {}).inject({}) {|h, e| h[e.first] = e.last.map {|a| {error: a} } and h}
      {
        data: data,
        metadata: metadata,
        errors: errors
      }
    rescue MultiJson::ParseError, TypeError => ex
      {errors: {base: [{error: ex.message}]}}
    end
  end
end