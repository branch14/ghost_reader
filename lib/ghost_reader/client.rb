require 'excon'
require 'json'

module GhostReader
  class Client

    attr_accessor :config, :last_modified

    def initialize(conf=nil)
      self.config = OpenStruct.new(default_config.merge(conf || {}))
      config.logger ||= Logger.new(config.logfile || STDOUT)
      config.logger.debug "Initialized client."
    end

    # returns a Head with three keys
    #   :timestamp (the value of last-modified header)
    #   :data (a nested Hash of translations)
    #   :status (the reponse status)
    def initial_request
      config.logger.debug "Client peforming initial request."
      response = service.get
      config.logger.debug "Client returned from inital request."
      self.last_modified = response.get_header('Last-Modified')
      build_head(response)
    end

    # returns true if redirected, false otherwise
    def reporting_request(data)
      response = service.post(:body => "data=#{data.to_json}")
      config.logger.error "Reporting request not redirected" unless response.status == 302
      { :status => response.status }
    end

    # returns a Head with three keys
    #   :timestamp (the value of last-modified header)
    #   :data (a nested Hash of translations)
    #   :status (the reponse status)
    def incremental_request
      headers = { 'If-Modified-Since' => self.last_modified }
      response = service.get(:headers => headers)
      self.last_modified = response.get_header('Last-Modified')
      build_head(response)
    end

    private

    def build_head(excon_response)
      { :status => excon_response.status }.tap do |result|
        result[:data] = JSON.parse(excon_response.body) if excon_response.status == 200
      end
    end

    def service
      @service ||= Excon.new(address)
    end

    def address
      raise 'no api_key provided' if config.api_key.nil?
      @address ||= config.uri.sub(':api_key', config.api_key)
    end

    def default_config
      {
        :uri => 'http://ghost.panter.ch/api/:api_key/translations.json',
        :api_key => nil
      }
    end

  end
end
