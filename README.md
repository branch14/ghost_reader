GhostReader
===========

GhostReader is an alternative I18n backend which makes use of the
GhostWriter service.

## Usage

### Gemfile

    gem 'ghost_reader', '~> 1.1.1'

### config/initializers/ghost_reader.rb

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

## Configuration

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

## TODO

* implement counting, for statistics
* document all config options

## THANKS

All work on GhostReader is supported by Panter LLC, Zurich,
Switzerland. http://panter.ch

Special thanks go to Andreas Koenig, for his inital version of
GhostReader, and Peco Danajlovski for helping with the rewrite.


