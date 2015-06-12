require_relative "test_helper"

class WorkerTest < Test::Unit::TestCase
  include CPW::Client::Resources

  def test_stage_name
    assert_equal "split", CPW::Worker::Split.stage_name
  end

  def test_queue_name
    assert_equal "SPLIT_TEST_QUEUE", CPW::Worker::Split.queue_name
  end

  def test_class_for
    assert_equal CPW::Worker::Finish, CPW::Worker::Base.class_for("finish")
    assert_equal CPW::Worker::Finish, CPW::Worker::Base.class_for("finish.rb")
  end

  def test_can_stage_when_start_workflow
    stub_request(:get, 'http://www.example.com/api/ingests/1').to_return_json(ingest: {"id"=>1, "upload_id"=>1, "document_id"=>1, "type"=>"Ingest::AudioIngest", "status"=>2, "updated_at"=>"2015-06-03T23:05:55.639Z", "created_at"=>"2015-06-03T20:03:54.260Z", "started_at"=>"2015-06-03T20:04:46.838Z", "stopped_at"=>nil, "restarted_at"=>nil, "reset_at"=>nil, "removed_at"=>nil, "finished_at"=>nil, "progress"=>95, "messages"=>{}, "stage"=>nil, "iteration"=>0, "busy"=>false, "terminate"=>false, "uid"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8", "workflow_stage_names"=>["start", "harvest", "transcode", "split", "crowdout", "archive", "finish"], "previous_stage_name"=>"split", "next_stage_name"=>"archive", "upload"=>{"s3_key"=>"3bpkl6513a", "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb", "recorded_at"=>"2015-06-03T20:03:54.251Z", "id"=>62, "file_name"=>"genesis-1-1-en-us.m4a", "file_type"=>"audio/x-m4a", "file_size"=>1032703, "s3_url"=>"http://s3.amazonaws.com/vz-dev-dropbox/3bpkl6513a", "locale"=>"en-US", "slug"=>"07ijT1H", "title"=>"Genesis 1 1 en us", "description"=>"", "tag_list"=>[], "privacy"=>["public"], "status"=>2, "type"=>"Upload::AudioUpload", "progress"=>95, "events"=>["stop", "remove", "restart"], "updated_at"=>"2015-06-03T20:03:54.251Z", "created_at"=>"2015-06-03T20:03:54.251Z"}, "document"=>{"id"=>79, "title"=>"Genesis 1 1 en us", "description"=>"", "html"=>nil, "rich_text"=>nil, "text"=>nil, "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"}} )
    start_worker = CPW::Worker::Start.new
    start_worker.body = {"ingest_id" => 1, "workflow" => true}
    start_worker.ingest = Ingest.find(1)
    assert_equal true, start_worker.send(:can_stage?, nil)
  end

  def test_can_not_stage_when_workflow_started
    stub_request(:get, 'http://www.example.com/api/ingests/1').to_return_json(ingest: {"id"=>1, "upload_id"=>1, "document_id"=>1, "type"=>"Ingest::AudioIngest", "status"=>2, "updated_at"=>"2015-06-03T23:05:55.639Z", "created_at"=>"2015-06-03T20:03:54.260Z", "started_at"=>"2015-06-03T20:04:46.838Z", "stopped_at"=>nil, "restarted_at"=>nil, "reset_at"=>nil, "removed_at"=>nil, "finished_at"=>nil, "progress"=>95, "messages"=>{}, "stage"=>"start", "iteration"=>0, "busy"=>false, "terminate"=>false, "uid"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8", "workflow_stage_names"=>["start", "harvest", "transcode", "split", "crowdout", "archive", "finish"], "previous_stage_name"=>"split", "next_stage_name"=>"archive", "upload"=>{"s3_key"=>"3bpkl6513a", "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb", "recorded_at"=>"2015-06-03T20:03:54.251Z", "id"=>62, "file_name"=>"genesis-1-1-en-us.m4a", "file_type"=>"audio/x-m4a", "file_size"=>1032703, "s3_url"=>"http://s3.amazonaws.com/vz-dev-dropbox/3bpkl6513a", "locale"=>"en-US", "slug"=>"07ijT1H", "title"=>"Genesis 1 1 en us", "description"=>"", "tag_list"=>[], "privacy"=>["public"], "status"=>2, "type"=>"Upload::AudioUpload", "progress"=>95, "events"=>["stop", "remove", "restart"], "updated_at"=>"2015-06-03T20:03:54.251Z", "created_at"=>"2015-06-03T20:03:54.251Z"}, "document"=>{"id"=>79, "title"=>"Genesis 1 1 en us", "description"=>"", "html"=>nil, "rich_text"=>nil, "text"=>nil, "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"}} )
    worker = CPW::Worker::Start.new
    worker.body = {"ingest_id" => 1, "workflow" => true}
    worker.ingest = Ingest.find(1)
    assert_equal false, worker.send(:can_stage?, "start")
  end

  def test_can_stage_when_workflow_harvest_previous_stage_start
    stub_request(:get, 'http://www.example.com/api/ingests/1').to_return_json(ingest: {"id"=>1, "upload_id"=>1, "document_id"=>1, "type"=>"Ingest::AudioIngest", "status"=>2, "updated_at"=>"2015-06-03T23:05:55.639Z", "created_at"=>"2015-06-03T20:03:54.260Z", "started_at"=>"2015-06-03T20:04:46.838Z", "stopped_at"=>nil, "restarted_at"=>nil, "reset_at"=>nil, "removed_at"=>nil, "finished_at"=>nil, "progress"=>95, "messages"=>{}, "stage"=>"start", "iteration"=>0, "busy"=>false, "terminate"=>false, "uid"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8", "workflow_stage_names"=>["start", "harvest", "transcode", "split", "crowdout", "archive", "finish"], "previous_stage_name"=>"split", "next_stage_name"=>"archive", "upload"=>{"s3_key"=>"3bpkl6513a", "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb", "recorded_at"=>"2015-06-03T20:03:54.251Z", "id"=>62, "file_name"=>"genesis-1-1-en-us.m4a", "file_type"=>"audio/x-m4a", "file_size"=>1032703, "s3_url"=>"http://s3.amazonaws.com/vz-dev-dropbox/3bpkl6513a", "locale"=>"en-US", "slug"=>"07ijT1H", "title"=>"Genesis 1 1 en us", "description"=>"", "tag_list"=>[], "privacy"=>["public"], "status"=>2, "type"=>"Upload::AudioUpload", "progress"=>95, "events"=>["stop", "remove", "restart"], "updated_at"=>"2015-06-03T20:03:54.251Z", "created_at"=>"2015-06-03T20:03:54.251Z"}, "document"=>{"id"=>79, "title"=>"Genesis 1 1 en us", "description"=>"", "html"=>nil, "rich_text"=>nil, "text"=>nil, "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"}} )
    worker = CPW::Worker::Harvest.new
    worker.body = {"ingest_id" => 1, "workflow" => true}
    worker.ingest = Ingest.find(1)
    assert_equal true, worker.send(:can_stage?, "start")
  end

  def test_can_not_stage_when_workflow_harvest_runs_again
    stub_request(:get, 'http://www.example.com/api/ingests/1').to_return_json(ingest: {"id"=>1, "upload_id"=>1, "document_id"=>1, "type"=>"Ingest::AudioIngest", "status"=>2, "updated_at"=>"2015-06-03T23:05:55.639Z", "created_at"=>"2015-06-03T20:03:54.260Z", "started_at"=>"2015-06-03T20:04:46.838Z", "stopped_at"=>nil, "restarted_at"=>nil, "reset_at"=>nil, "removed_at"=>nil, "finished_at"=>nil, "progress"=>95, "messages"=>{}, "stage"=>"harvest", "iteration"=>0, "busy"=>false, "terminate"=>false, "uid"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8", "workflow_stage_names"=>["start", "harvest", "transcode", "split", "crowdout", "archive", "finish"], "previous_stage_name"=>"split", "next_stage_name"=>"archive", "upload"=>{"s3_key"=>"3bpkl6513a", "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb", "recorded_at"=>"2015-06-03T20:03:54.251Z", "id"=>62, "file_name"=>"genesis-1-1-en-us.m4a", "file_type"=>"audio/x-m4a", "file_size"=>1032703, "s3_url"=>"http://s3.amazonaws.com/vz-dev-dropbox/3bpkl6513a", "locale"=>"en-US", "slug"=>"07ijT1H", "title"=>"Genesis 1 1 en us", "description"=>"", "tag_list"=>[], "privacy"=>["public"], "status"=>2, "type"=>"Upload::AudioUpload", "progress"=>95, "events"=>["stop", "remove", "restart"], "updated_at"=>"2015-06-03T20:03:54.251Z", "created_at"=>"2015-06-03T20:03:54.251Z"}, "document"=>{"id"=>79, "title"=>"Genesis 1 1 en us", "description"=>"", "html"=>nil, "rich_text"=>nil, "text"=>nil, "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"}} )
    worker = CPW::Worker::Harvest.new
    worker.body = {"ingest_id" => 1, "workflow" => true}
    worker.ingest = Ingest.find(1)
    assert_equal false, worker.send(:can_stage?, "harvest")
  end

  def test_can_always_stage_when_not_in_workflow
    stub_request(:get, 'http://www.example.com/api/ingests/1').to_return_json(ingest: {"id"=>1, "upload_id"=>1, "document_id"=>1, "type"=>"Ingest::AudioIngest", "status"=>2, "updated_at"=>"2015-06-03T23:05:55.639Z", "created_at"=>"2015-06-03T20:03:54.260Z", "started_at"=>"2015-06-03T20:04:46.838Z", "stopped_at"=>nil, "restarted_at"=>nil, "reset_at"=>nil, "removed_at"=>nil, "finished_at"=>nil, "progress"=>95, "messages"=>{}, "stage"=>"harvest", "iteration"=>0, "busy"=>false, "terminate"=>false, "uid"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8", "workflow_stage_names"=>["start", "harvest", "transcode", "split", "crowdout", "archive", "finish"], "previous_stage_name"=>"split", "next_stage_name"=>"archive", "upload"=>{"s3_key"=>"3bpkl6513a", "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb", "recorded_at"=>"2015-06-03T20:03:54.251Z", "id"=>62, "file_name"=>"genesis-1-1-en-us.m4a", "file_type"=>"audio/x-m4a", "file_size"=>1032703, "s3_url"=>"http://s3.amazonaws.com/vz-dev-dropbox/3bpkl6513a", "locale"=>"en-US", "slug"=>"07ijT1H", "title"=>"Genesis 1 1 en us", "description"=>"", "tag_list"=>[], "privacy"=>["public"], "status"=>2, "type"=>"Upload::AudioUpload", "progress"=>95, "events"=>["stop", "remove", "restart"], "updated_at"=>"2015-06-03T20:03:54.251Z", "created_at"=>"2015-06-03T20:03:54.251Z"}, "document"=>{"id"=>79, "title"=>"Genesis 1 1 en us", "description"=>"", "html"=>nil, "rich_text"=>nil, "text"=>nil, "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"}} )
    worker = CPW::Worker::Start.new
    worker.body = {"ingest_id" => 1, "workflow" => false}
    worker.ingest = Ingest.find(1)
    assert_equal true, worker.send(:can_stage?, "start")
  end
end