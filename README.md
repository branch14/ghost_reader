GhostReader
===========

GhostReader is an alternative I18n backend which makes use of the
GhostWriter service (https://github.com/branch14/ghost_writer).

## Usage

### Gemfile

    gem 'ghost_reader'

### For development & staging

#### config/initializers/ghost_reader.rb

    unless Rails.env.test?
      config = {
        :report_interval => 42, # secs
        :retrieval_interval => 23, # secs
        :fallback => I18n.backend,
        :logfile => File.join(Rails.root, %w(log ghostwriter.log)),
        :service => {
          :api_key => '<here_goes_your_api_key>'
        }
      }
      
      I18n.backend = GhostReader::Backend.new(config)
    end

#### Configuration

* 'report interval' is the delay in seconds between subsequent POST
  requests (reporting requests), which report missing translations. 
* 'retrieval_interval' is the delay in seconds between subsequent GET
  requests (incremental requests), which retrieve updated translations.
* 'fallback' point to the I18n backend wich should be used as a
  fallback.
* 'logfile' is the path to a optional, separate logfile. If this is
  omitted, log messages go to standard out.
* 'service' holds a hash with connection details.
  - 'api_key' is a GhostWriter API key.
  - 'host' is the hostname, optionally with port.
  - 'protocol' is either 'http' or 'https'
  - 'uri' is the complete uri with the folling keys, which will be
    replaced: :protocol, :host, :api_key

### For Live

In a live system you typically don't want to depend on another system,
so we'll just go with a static export of translations.

    # specify where to get the static file from
    echo 'static: https://<ghostservice>/system/static/<apikey>.yml' >> config/ghost_reader.yml

    # in a cron job do this
    rake ghost_reader:poll

The rake task will rewrite config/locales/ghost_reader.yml if it
changed and touch tmp/restart.txt to make passenger restart the
application.

It's a good idea to delete all other translations files on this
system.

## TODO

* implement counting, for statistics
* document all config options

## THANKS

All work on GhostReader is supported by Panter LLC, Zurich,
Switzerland. http://panter.ch

Special thanks go to Andreas Koenig, for his inital version of
GhostReader, and Peco Danajlovski for helping with the rewrite.


