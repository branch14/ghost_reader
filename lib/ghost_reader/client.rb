require 'excon'
require 'json'

module GhostReader
  class Client

    attr_accessor :config, :last_modified

    def initialize(conf=nil)
      self.config = OpenStruct.new(default_config.merge(conf || {}))
      config.logger ||= Logger.new(config.logfile || STDOUT)
    end

    # returns a Head with three keys
    #   :timestamp (the value of last-modified header)
    #   :data (a nested Hash of translations)
    #   :status (the reponse status)
    def initial_request
      response = connect_with_retry
      self.last_modified = response.get_header('Last-Modified')
      build_head(response)
    end

    # returns true if redirected, false otherwise
    def reporting_request(data)
      response = connect_with_retry(:post, :body => "data=#{data.to_json}")
      log("Reporting request not redirected", :error) unless response.status == 302
      { :status => response.status }
    end

    # returns a Head with three keys
    #   :timestamp (the value of last-modified header)
    #   :data (a nested Hash of translations)
    #   :status (the reponse status)
    def incremental_request
      headers = { 'If-Modified-Since' => self.last_modified }
      response = connect_with_retry(:get, :headers => headers)
      self.last_modified = response.get_header('Last-Modified') if response.status == 200
      build_head(response)
    end

    # this is just a wrapper to have a log message when the field is set
    def last_modified=(value)
      log "Last-Modified: #{value}"
      @last_modified = value
    end

    private

    def build_head(excon_response)
      { :status => excon_response.status }.tap do |result|
        result[:data] = JSON.parse(excon_response.body) if excon_response.status == 200
      end
    end

    def service
      Excon.new(address)
    end

    def address
      raise 'no api_key provided' if config.api_key.nil?
      @address ||= config.uri.
        sub(':protocol', config.protocol).
        sub(':host',     config.host).
        sub(':api_key',  config.api_key)
    end

    # Wrapper method for retrying the connection
    #   :method - http method (post and get supported at the moment)
    #   :params - parameters sent to the service (excon)
    def connect_with_retry(method = :get, params = {})
      log "Request: #{method} #{params.inspect}"
      retries = self.config.connection_retries
      while (retries > 0) do
        response = service.request(params.merge(:method => method))

        if response.status == 408
          log "Connection time-out. Retrying... #{retries}", :error
          retries -= 1
        else
          retries = 0 # There is no timeout, no need to retry
        end
      end
      response
    end

    def default_config
      {
        :protocol => 'http',
        :host => 'ghost.panter.ch',
        :api_key => nil,
        :uri => ':protocol://:host/api/:api_key/translations.json',
        :connection_retries => 3
      }
    end

    def log(msg, level=:debug)
      config.logger.send(level, "[#{$$}] #{msg}")
    end

  end
end
