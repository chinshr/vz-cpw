ENV['CPW_ENV'] = "test"
require "rubygems"
require "test/unit"
require "byebug"
require "cpw"
require "mocha/test_unit"
require "webmock/test_unit"

# Require support files
Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

WebMock.disable_net_connect!(:net_http_connect_on_start => true)

class Test::Unit::TestCase

  # Add global extensions to the test case class here

  # E.g. "/Users/foo/work/test"
  def test_root
    File.dirname(__FILE__)
  end

  def fixtures_root
    "#{test_root}/fixtures"
  end

  protected

  def stub_ingest(attributes = {})
    attributes = attributes.reverse_merge({"id"=>1, "upload_id"=>1, "document_id"=>1, "type"=>"Ingest::AudioIngest", "status"=>2, "updated_at"=>"2015-06-03T23:05:55.639Z", "created_at"=>"2015-06-03T20:03:54.260Z", "started_at"=>"2015-06-03T20:04:46.838Z", "stopped_at"=>nil, "restarted_at"=>nil, "reset_at"=>nil, "removed_at"=>nil, "finished_at"=>nil, "progress"=>20, "messages"=>{}, "stage"=>"harvest_stage", "stages" => ["begin_stage", "harvest_stage", "transcode_stage", "split_stage", "archive_stage", "end_stage"], "iteration"=>0, "busy"=>false, "terminate"=>false, "uid"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8", "upload"=>{"s3_key"=>"3bpkl6513a", "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb", "recorded_at"=>"2015-06-03T20:03:54.251Z", "id"=>62, "file_name"=>"genesis-1-1-en-us.m4a", "file_type"=>"audio/x-m4a", "file_size"=>1032703, "s3_url"=>"http://s3.amazonaws.com/vz-dev-dropbox/3bpkl6513a", "locale"=>"en-US", "slug"=>"07ijT1H", "title"=>"Genesis 1 1 en us", "description"=>"", "tag_list"=>[], "privacy"=>["public"], "status"=>2, "type"=>"Upload::AudioUpload", "progress"=>95, "events"=>["stop", "remove", "restart"], "updated_at"=>"2015-06-03T20:03:54.251Z", "created_at"=>"2015-06-03T20:03:54.251Z"}, "document"=>{"id"=>79, "title"=>"Genesis 1 1 en us", "description"=>"", "html"=>nil, "rich_text"=>nil, "text"=>nil, "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"}})
    stub_request(:get, "http://www.example.com/api/ingests/#{attributes['id']}").to_return_json({ingest: attributes})
  end

end
