require 'test_helper.rb'

class IngestTest < Test::Unit::TestCase
  def setup
    stub_requests
    @ingest1 = Ingest.find(1)
    @ingest2 = Ingest.find(2)
  end

  def test_state_inquiry
    assert_equal false, @ingest1.created?
    assert_equal false, @ingest1.starting?
    assert_equal true, @ingest1.started?
    assert_equal false, @ingest1.stopping?
    assert_equal false, @ingest1.stopped?
    assert_equal false, @ingest1.resetting?
    assert_equal false, @ingest1.reset?
    assert_equal false, @ingest1.finished?
    assert_equal false, @ingest1.restarting?
  end

  def test_stage_inquiry
    assert_equal false, @ingest1.begin_stage?
    assert_equal false, @ingest1.harvest_stage?
    assert_equal true, @ingest1.transcode_stage?
    assert_equal false, @ingest1.split_stage?
    assert_equal false, @ingest1.archive_stage?
    assert_equal false, @ingest1.end_stage?
  end

  def test_state
    assert_equal :started, @ingest1.state
  end

  def test_stages
    assert_equal [:begin_stage, :harvest_stage, :transcode_stage, :split_stage, :archive_stage, :end_stage], @ingest1.stages
  end

  def test_stage_names
    assert_equal ["begin", "harvest", "transcode", "split", "archive", "end"], @ingest1.stage_names
  end

  def test_stage
    assert_equal :transcode_stage, @ingest1.stage
  end

  def test_stage_name
    assert_equal "transcode", @ingest1.stage_name
  end

  def test_previous_stage
    assert_equal :harvest_stage, @ingest1.previous_stage
    assert_equal :begin_stage, @ingest1.previous_stage(:harvest_stage)
    assert_equal nil, @ingest1.previous_stage(:begin_stage)
    assert_equal nil, @ingest1.previous_stage(nil)

    assert_equal nil, Ingest.new(stage: "begin_stage", stages: ["begin_stage", "harvest_stage"]).previous_stage
    assert_equal :begin_stage, Ingest.new(stage: "harvest_stage", stages: ["begin_stage", "harvest_stage"]).previous_stage
  end

  def test_previous_stage_name
    assert_equal "harvest", @ingest1.previous_stage_name
    assert_equal "begin", @ingest1.previous_stage_name("harvest")
    assert_equal "begin", @ingest1.previous_stage_name("harvest_stage")
    assert_equal "begin", @ingest1.previous_stage_name(:harvest_stage)

    assert_equal nil, @ingest1.previous_stage_name("begin")
    assert_equal nil, @ingest1.previous_stage_name(:begin_stage)

    assert_equal nil, @ingest1.previous_stage_name(nil)
  end

  def test_next_stage
    assert_equal :split_stage, @ingest1.next_stage
  end

  def test_next_stage_name
    assert_equal "split", @ingest1.next_stage_name
    assert_equal nil, Ingest.new(stage: "harvest_stage", stages: ["begin_stage", "harvest_stage"]).next_stage
    assert_equal :harvest_stage, Ingest.new(stage: "begin_stage", stages: ["begin_stage", "harvest_stage"]).next_stage
  end

  def test_handle
    assert_equal "3bpkl6513a", @ingest1.handle
  end

  def test_s3_origin_bucket_name
    assert_equal "vz-test-origin", @ingest1.s3_origin_bucket_name
  end

  def test_s3_origin_key
    assert_equal "3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a", @ingest1.s3_origin_key
    assert_equal "4a0b3b08-e7d4-492f-b260-4c6f680ef0f9/3bpkl6513b", @ingest2.s3_origin_key
  end

  def test_s3_origin_url
    assert_equal "http://s3.amazonaws.com/vz-test-origin/3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a", @ingest1.s3_origin_url
    assert_equal "http://s3.amazonaws.com/vz-test-origin/4a0b3b08-e7d4-492f-b260-4c6f680ef0f9/3bpkl6513b", @ingest2.s3_origin_url
  end

  def has_s3_source_url?
    assert_equal true, @ingest1.has_s3_source_url?
  end

  def has_ms_source_url?
    assert_equal false, @ingest1.has_ms_source_url?
  end

  def has_source_url?
    assert_equal true, @ingest1.has_source_url?
  end

  protected

  def stub_requests
    stub_request(:get, 'http://www.example.com/api/ingests/1').to_return_json({
      "ingest": {
        "id"=>1, "upload_id"=>1, "document_id"=>1,
        "type"=>"Ingest::AudioIngest", "status"=>2,
        "updated_at"=>"2015-06-03T23:05:55.639Z",
        "created_at"=>"2015-06-03T20:03:54.260Z",
        "started_at"=>"2015-06-03T20:04:46.838Z",
        "stopped_at"=>nil, "restarted_at"=>nil,
        "reset_at"=>nil, "removed_at"=>nil,
        "finished_at"=>nil, "progress"=>20,
        "handle"=>"3bpkl6513a",
        "file_name"=>"genesis-1-1-en-us.m4a",
        "file_type"=>"audio/x-m4a",
        "file_size"=>1032703,
        "messages"=>{},
        "stage"=>"transcode_stage",
        "stages" => ["begin_stage", "harvest_stage", "transcode_stage", "split_stage", "archive_stage", "end_stage"],
        "iteration"=>0, "busy"=>false, "terminate"=>false,
        "uid"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8",
        "source_url"=>"http://s3.amazonaws.com/vz-test-dropbox/3bpkl6513a",
        "origin_url"=>nil,
        "upload"=>{
          "id"=>62,
          "s3_key"=>"3bpkl6513a",
          "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb",
          "recorded_at"=>"2015-06-03T20:03:54.251Z",
          "source_url"=>"http://s3.amazonaws.com/vz-test-dropbox/3bpkl6513a",
          "locale"=>"en-US", "slug"=>"07ijT1H",
          "title"=>"Genesis 1 1 en us", "description"=>"",
          "tag_list"=>[], "privacy"=>["public"], "status"=>2,
          "type"=>"Upload::MediaUpload", "progress"=>95,
          "events"=>["stop", "remove", "restart"],
          "updated_at"=>"2015-06-03T20:03:54.251Z",
          "created_at"=>"2015-06-03T20:03:54.251Z"
        }, "document"=>{
          "id"=>79, "title"=>"Genesis 1 1 en us",
          "description"=>"", "html"=>nil, "rich_text"=>nil,
          "text"=>nil, "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"
        }
      }
    })

    stub_request(:get, 'http://www.example.com/api/ingests/1/tracks?any_of_types[]=document_track').to_return_json({"tracks": []})
    stub_request(:get, 'http://www.example.com/api/ingests/2').to_return_json({
      "ingest": {
        "id"=>2, "upload_id"=>1, "document_id"=>1,
        "type"=>"Ingest::AudioIngest", "status"=>2,
        "updated_at"=>"2015-06-03T23:05:55.639Z",
        "created_at"=>"2015-06-03T20:03:54.260Z",
        "started_at"=>"2015-06-03T20:04:46.838Z",
        "stopped_at"=>nil, "restarted_at"=>nil,
        "reset_at"=>nil, "removed_at"=>nil, "finished_at"=>nil,
        "progress"=>95, "messages"=>{}, "stage"=>"crowdout_stage",
        "iteration"=>0, "busy"=>false, "terminate"=>false,
        "handle"=>"3bpkl6513b",
        "file_name"=>"genesis-1-1-en-us.m4a",
        "file_type"=>"audio/x-m4a", "file_size"=>1032703,
        "uid"=>"4a0b3b08-e7d4-492f-b260-4c6f680ef0f9",
        "source_url"=>"https://www.youtube.com/watch?v=aORId5oBmCM",
        "origin_url"=>"http://s3.amazonaws.com/vz-test-origin/4a0b3b08-e7d4-492f-b260-4c6f680ef0f9/3bpkl6513b",
        "upload"=>{
          "id"=>62,
          "s3_key"=>"3bpkl6513a",
          "uid"=>"58481787-4bdc-4e6f-b709-b3d424f8abbb",
          "recorded_at"=>"2015-06-03T20:03:54.251Z",
          "file_name"=>"genesis-1-1-en-us.m4a",
          "file_type"=>"audio/x-m4a", "file_size"=>1032703,
          "source_url"=>"https://www.youtube.com/watch?v=aORId5oBmCM",
          "locale"=>"en-US", "slug"=>"07ijT1H",
          "title"=>"Genesis 1 1 en us", "description"=>"",
          "tag_list"=>[], "privacy"=>["public"], "status"=>2,
          "type"=>"Upload::MediaUpload", "progress"=>95,
          "events"=>["stop", "remove", "restart"],
          "updated_at"=>"2015-06-03T20:03:54.251Z",
          "created_at"=>"2015-06-03T20:03:54.251Z"
        }, "document"=>{
          "id"=>79, "title"=>"Genesis 1 1 en us", "description"=>"",
          "html"=>nil, "rich_text"=>nil, "text"=>nil,
          "uid"=>"d26e0603-06dd-4ed7-814d-dafc1fbae635"
        }
      }
    })

    stub_request(:get, 'http://www.example.com/api/ingests/2/tracks?any_of_types[]=document_track').to_return_json({
      "tracks": [{
        "id"=>1, "uid"=>"98c613d8-56f9-491d-86dd-9dc7c646a4ff",
        "ingest_iteration"=>0,
        "s3_key"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a",
        "s3_url"=>"http://s3.amazonaws.com/vz-dev-origin/3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a",
        "s3_mp3_key"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a.ac2.ab128k.mp3",
        "s3_mp3_url"=>"http://s3.amazonaws.com/vz-dev-origin/3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a.ac2.ab128k.mp3",
        "s3_waveform_json_key"=>"3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a.ac2.waveform.json",
        "s3_waveform_json_url"=>"http://s3.amazonaws.com/vz-dev-origin/3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a.ac2.waveform.json",
        "updated_at"=>"2015-06-03T20:06:10.889Z",
        "type"=>"Track::DocumentTrack", "ingest_id"=>57,
        "document_id"=>79,
        "mp3_stream_url"=>"http://vz-dev-origin.s3.amazonaws.com/3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a.ac2.ab128k.mp3?AWSAccessKeyId=AKIAJB7Z3FGKOUXPZ7ZQ&Expires=1433910126&Signature=Zms0bz6Hd8ZQyI2ncSE%2F2IBUlh4%3D&response-content-type=audio%2Fmpeg",
        "waveform_json_stream_url"=>"http://vz-dev-origin.s3.amazonaws.com/3a0b3b08-e7d4-492f-b260-4c6f680ef0f8/3bpkl6513a.ac2.waveform.json?AWSAccessKeyId=AKIAJB7Z3FGKOUXPZ7ZQ&Expires=1433910126&Signature=rdqJ8%2BlHZtFl9slvt20BjHPJtaE%3D&response-content-type=application%2Fjson",
        "duration"=>34.16, "start_at"=>"2015-06-03T20:03:54.000Z",
        "end_at"=>"2015-06-03T20:04:29.000Z",
        "created_at"=>"2015-06-03T20:04:56.664Z"
      }]
    })
  end
end