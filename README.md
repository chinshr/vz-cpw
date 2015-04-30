# Content Processing Workflow (CPW)

Processes audio/video content, transacribes, indexes.

## Installation

Add this line to your application's Gemfile:

    gem 'cpw'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cpw

## Usage

### Start Server

    cpw server

or

    cpw s

Type `cpw help` for more help.

Or, manually starting up the server:

    bundle exec shoryuken -r cpw.rb -C config/shoryuken.yml

### Start Console

    cpw console

or

    cpw c

Or, manually startup an IRB session:

    bundle exec irb -r "cpw"

### Send a message

    sqs = AWS::SQS.new
    queue = sqs.queues.named("ARCHIVE_DEVELOPMENT_QUEUE")
    queue.send_message({ingest_id: 46}.to_json)

## Developer Resources

* AWS SQS messaging example -- http://mauricio.github.io/2014/09/01/make-the-most-of-sqs.html
* Pocketsphinx Ruby gem -- https://github.com/watsonbox/pocketsphinx-ruby?utm_source=rubyweekly&utm_medium=email
* Handles API nicely in AR model like fashion -- https://github.com/balvig/spyke
* How to write a gem -- http://howistart.org/posts/ruby/1
* Concurrent workers -- http://www.toptal.com/ruby/ruby-concurrency-and-parallelism-a-practical-primer
* Shoryuken, like Sidekiq for SQS -- https://github.com/phstc/shoryuken
* Ruby concurrency -- http://www.toptal.com/ruby/ruby-concurrency-and-parallelism-a-practical-primer
* SQS to the rescue -- http://www.pablocantero.com/blog/2014/11/29/sqs-to-the-rescue/
* Spyke nested attributes -- https://github.com/balvig/spyke/issues/28