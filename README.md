# Content Processing Workflow (CPW)

Processes audio/video content, transacribes, indexes.

## Installation

Add this line to your application's Gemfile:

    gem 'cpw'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cpw

## Server Installation

The following instructions describe all necessary steps to install CPW and its dependencies on 3rd party tools on a freshly created AWS instance of Ubuntu 64-bit server (ami-d05e75b8).

### SSH + PEM

From your terminal ssh into server (first, get `vz-cpw-ec2.pem` from [vz-certs](https://github.com/vzo/vz-certs)):

    ssh -i ~/.ssh/vz-cpw-ec2.pem ubuntu@<public-ip/dn>

Example:

    ssh -i ~/.ssh/vz-cpw-ec2.pem ubuntu@54.175.249.21

### Install Ruby

Install standard package (ruby 1.9.3):

    sudo apt-get install ruby

### Install RVM

Use these [installation instructions](https://rvm.io/rvm/install). Install public key first, then install RVM Ruby.

### Git + GitHub SSH keys

    sudo apt-get install git

Follow [Generating SSH keys instructions](https://help.github.com/articles/generating-ssh-keys/#platform-linux) to get have access to the [VZO GitHub repo](https://github.com/vzo).

### Install `ffmpeg`

Use the following [this official script](https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu) or [this alternative script](https://gist.github.com/xdamman/e4f713c8cd1a389a5917). Note: Update the /etc/apt/sources.list using this http://superuser.com/questions/467774/how-to-install-libfaac-dev

### Install `sox`

    sudo apt-get install sox

### Install `wav2json`

Follow these [installation instructions](https://github.com/beschulz/wav2json).

### Install Sphinxbase + Pocketsphinx

#### Install Prerequisites

    sudo apt-get install bison
    sudo apt-get install python-dev
    sudo apt-get install swig

#### Install SphinxBase from GitHub (Source)

The following steps were derived from [these Homebrew scripts](https://github.com/watsonbox/homebrew-cmu-sphinx).

    cd
    git clone https://github.com/cmusphinx/sphinxbase
    cd sphinxbase
    ./autogen.sh
    make
    sudo make install

Note: Setup shared library path before proceeding. Add the following lines at the end of `~/.bashrc` or system wide in `/etc/environment`:

    export LD_LIBRARY_PATH=/usr/local/lib
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

#### Install Pocketsphinx from GitHub (Source)

    cd
    git clone git@github.com:cmusphinx/pocketsphinx.git
    cd pocketsphinx
    ./autogen.sh
    ./configure --prefix=/usr/local
    make clean all
    make check
    sudo make install

Test pocketsphinx on command line:

    $ which pocketsphinx_continuous
    # /usr/local/bin/pocketsphinx_continuous
    $ pocketsphinx_continuous # -inmic yes

#### Download Language Models

Downloading additional language models (here example French), which are located [here](http://sourceforge.net/projects/cmusphinx/files/Acoustic%20and%20Language%20Models/):

    wget -O lium_french_f0.tar.gz http://sourceforge.net/projects/cmusphinx/files/Acoustic%20and%20Language%20Models/French/cmusphinx-fr-5.2.tar.gz/download
    tar -xvzf lium_french_f0.tar.gz
    cd cmusphinx-fr-5.2
    mkdir -p `pkg-config --variable=modeldir pocketsphinx`/hmm/fr_FR/french_f0
    mv * `pkg-config --variable=modeldir pocketsphinx`/hmm/fr_FR/french_f0

    wget -O french3g62K.lm.dmp http://sourceforge.net/projects/cmusphinx/files/Acoustic%20and%20Language%20Models/French%20Language%20Model/french3g62K.lm.dmp/download
    sudo mkdir -p `pkg-config --variable=modeldir pocketsphinx`/lm/fr_FR/
    sudo mv french3g62K.lm.dmp `pkg-config --variable=modeldir pocketsphinx`/lm/fr_FR/

    wget -O frenchWords62K.dic http://sourceforge.net/projects/cmusphinx/files/Acoustic%20and%20Language%20Models/French%20Language%20Model/frenchWords62K.dic/download
    sudo mv frenchWords62K.dic `pkg-config --variable=modeldir pocketsphinx`/lm/fr_FR/

Note: From [Ubuntu (French) Forum](http://doc.ubuntu-fr.org/pocketsphinx)

### Install CPW

Install correct Ruby version (or, same as in `.ruby-version`):

    rvm install ruby-2.1.7
    rvm --default use 2.1.7
    ruby -v # check

Clone repo into home folder:

    cd
    git clone git@github.com:vzo/vz-cpw.git
    cd vz-cpw

Note: Ruby 2.1.7 requires lates gmp libraries, install with `sudo apt-get install libgmp3-dev`.

Install bundler:

    sudo apt-get install bundler
    gem install bundler

Install `libcurl` native extension:

    apt-get install libcurl4-gnutls-dev

Install gems:

    bundle install
    rake check

If all dependencies are installed correctly you should see following output:

    Checking tools...
    checking for ruby... yes
    checking for rvm... yes
    checking for git... yes
    checking for ffmpeg... yes
    checking for sox... yes
    checking for wav2json... yes
    checking for pocketsphinx_continuous... yes

Create a `.env` in the CPW root folder as the core credentials are not stored in the Git repo.

    vi .env
    export CLIENT_KEY="<get-client-key-from-vz-service>"
    export DEVICE_UID="aws-ec2-vz-cpw"
    export USER_EMAIL="cpw@voyz.es"
    export USER_PASSWORD="<get-cpw-password-from-vz-service>"
    export S3_AWS_REGION="us-east-1"
    export S3_URL="http://s3.amazonaws.com"
    export S3_KEY="<s3-key>"
    export S3_SECRET="s3-secret"

Test to launch CPW console in production environment:

    CPW_ENV=production cpw c

### Launch Server

Create SQS queues in the production enviroment:

    CPW_ENV=production rake sqs:queues:create

Start the server:

    CPW_ENV=production bundle exec shoryuken -v -r cpw.rb -C config/shoryuken.yml

### Configure Monit

Download and start `monit`.

    sudo apt-get install monit
    sudo monit

Create a shared folder and sub-folders (for pids, log, etc.)

    mkdir ~/shared
    mkdir ~/shared/pids
    mkdir ~/shared/log

Create `shoryuken.monitrc` file

    sudo touch /etc/monit/conf.d/shoryuken.monitrc
    sudo chmod 0644 /etc/monit/conf.d/shoryuken.monitrc

Edit `sudo vi /etc/monit/conf.d/shoryuken.monitrc`, add:

    check process shoryuken
      with pidfile /home/ubuntu/shared/pids/shoryuken.pid
      start program = "/bin/su - ubuntu -c 'cd /home/ubuntu/vz-cpw/ && CPW_ENV=production bundle exec shoryuken -r cpw.rb -L /home/ubuntu/shared/log/shoryuken.log -C /home/ubuntu/vz-cpw/config/shoryuken.yml -P /home/ubuntu/shared/pids/shoryuken.pid  2>&1 | logger -t shoryuken'" with timeout 90 seconds
      stop program = "/bin/su - ubuntu -c 'kill -s TERM `cat /home/ubuntu/shared/pids/shoryuken.pid`'" with timeout 90 seconds
      group shoryuken_cpw_group

New `shoryuken.monitrc` with pulling new repo, bundling:

    check process shoryuken
      with pidfile /home/ubuntu/shared/pids/shoryuken.pid
      start program = "/bin/su - ubuntu -c 'cd /home/ubuntu/vz-cpw/ && git pull && rvm gemset use vz-cpw && bundle && CPW_ENV=production bundle exec shoryuken -r cpw.rb -L /home/ubuntu/shared/log/shoryuken.log -C /home/ubuntu/vz-cpw/config/shoryuken.yml -P /home/ubuntu/shared/pids/shoryuken.pid  2>&1 | logger -t shoryuken'" with timeout 90 seconds
      stop program = "/bin/su - ubuntu -c '~/vz-cpw/bin/server/stop && kill -s TERM `cat /home/ubuntu/shared/pids/shoryuken.pid`'" with timeout 90 seconds
      group shoryuken_cpw_group

Next, you should check the syntax of your monit file using:

    sudo monit -t

If everything is OK, start CPW with:

    sudo monit start shoryuken

You should see the CPW appear in the process list using `ps -ef`. If shoryuken shows up in the process, check if the PID file is created correctly in `~/shared/pids`. Tail the log at `tail -100 /var/log/monit.log`

## Development Environment Usage

### Start Server

    cpw server

or

    cpw s

Type `cpw help` for more help.

Or, manually starting up the server:

    CPW_ENV=development bundle exec shoryuken -r cpw.rb -C config/shoryuken.yml

### Start Console

    cpw console

or

    cpw c

Or, manually startup an IRB session:

    bundle exec irb -r "cpw"

On the CPW console, in order to manually test workers, you can start a one-off worker (without going through the rest of the workflow), like this:

    CPW::Worker::Crowdout.perform_test({"ingest_id" => 46})

If you want to start the entire workflow, add the `workflow` key in the body:

    CPW::Worker::Start.perform_test({"ingest_id" => 46, "workflow" => true})

### Send a message

    sqs = AWS::SQS.new
    queue = sqs.queues.named("START_DEVELOPMENT_QUEUE")
    queue.send_message({ingest_id: 46, workflow: true}.to_json)

## Tools Installation

### wav2json

Mac: https://github.com/beschulz/wav2json#on-max-os


## Developer Resources

* AWS SQS messaging example -- http://mauricio.github.io/2014/09/01/make-the-most-of-sqs.html
* Pocketsphinx Ruby gem -- https://github.com/watsonbox/pocketsphinx-ruby
* Handles API nicely in AR model like fashion -- https://github.com/balvig/spyke
* How to write a gem -- http://howistart.org/posts/ruby/1
* Concurrent workers -- http://www.toptal.com/ruby/ruby-concurrency-and-parallelism-a-practical-primer
* Shoryuken, like Sidekiq for SQS -- https://github.com/phstc/shoryuken
* Ruby concurrency -- http://www.toptal.com/ruby/ruby-concurrency-and-parallelism-a-practical-primer
* SQS to the rescue -- http://www.pablocantero.com/blog/2014/11/29/sqs-to-the-rescue/
* Spyke nested attributes -- https://github.com/balvig/spyke/issues/28
* Converting audio to waveforms
  - https://github.com/bbcrd/audiowaveform
  - https://github.com/beschulz/wav2json
* Dual-microphone speech extraction -- http://www.dsp.agh.edu.pl/_media/pl:05337185.pdf
* Jin Zhou, Google Engineer, working on dual-microphone extraction, noise cancellation -- https://www.linkedin.com/in/ferryzhou
  - Speech enhancement: http://www.signalpro.net/se_dual2.htm
* Isabella aka semi-intelligent voice commands using pocketsphinx-ruby -- https://github.com/chrisvfritz/isabella
* Confidence measures for speech recognition -- http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.93.6890&rep=rep1&type=pdf
* Pocketsphinx utterance confidence -- http://sourceforge.net/p/cmusphinx/discussion/help/thread/48335932/
* Pocketsphinx ps_seg_prob for probablity score of the utterance looking promising -- http://www.speech.cs.cmu.edu/sphinx/doc/doxygen/pocketsphinx/pocketsphinx_8h.html#dfd45d93c3fc9de6b7be89d5417f6abb
* Noise cancellation C library -- https://github.com/nathesh/Noise-cancellation
* Speaker recognition, segmentation, clustering
  - Speaker diarization paper -- http://publications.idiap.ch/downloads/papers/2012/Vijayasenan_INTERSPEECH2012_2012.pdf
  - LIUM_SpkDiarization tool -- http://www-lium.univ-lemans.fr/diarization/doku.php/welcome
  - Segmentation diarization using LIUM tool -- http://cmusphinx.sourceforge.net/wiki/speakerdiarization
  - Speaker diarization projects from UC Berkeley -- http://multimedia.icsi.berkeley.edu/speaker-diarization/
  - StackOverflow question on speaker recognition: http://stackoverflow.com/questions/14248983/cmu-sphinx-for-voice-speaker-recognition
* Noise reduction tools (Ephraim Malach or Kalman) Sphinx recommendations -- http://cmusphinx.sourceforge.net/wiki/faq
* Concatenate wav files -- http://superuser.com/questions/587511/concatenate-multiple-wav-files-using-single-command-without-extra-file
* Ruby Pocketsphinx server -- https://github.com/alumae/ruby-pocketsphinx-server
* Kaldi GStreamer server -- https://github.com/alumae/kaldi-gstreamer-server
* Kaldi offline transcriber -- https://github.com/alumae/kaldi-offline-transcriber