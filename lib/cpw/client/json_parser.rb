module CPW
  class JsonParser < Faraday::Response::Middleware
    def parse(body)
      json     = MultiJson.load(body, symbolize_keys: true)
      data     = json[json.keys.reject {|k| [:code, :errors, :metadata].include?(k)}.first || :data] || {}
      metadata = json[:metadata] || {}

      if errors = data.delete(:errors)
        # {errors: { status: ["Event..."] }} -> {errors: { status: [{ error: 'Event...' }] }}
        errors = errors.inject({}) {|h,e| h[e.first] = e.last.inject([]) {|a,k| a << {error: k}}; h}
      else
        errors = json[:errors] || {}
        errors = errors.inject({}) {|h,e| h[e.first] = e.last.inject([]) {|a,k| a << {error: k}}; h}
      end
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