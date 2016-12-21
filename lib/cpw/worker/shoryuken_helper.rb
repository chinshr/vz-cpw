module CPW::Worker::ShoryukenHelper

  def self.included(base)
    base.send(:shoryuken_options, {
      queue: -> { base.queue_name },
      auto_delete: true,
      body_parser: :json,
      auto_visibility_timeout: true
    })
  end

end