require 'excon'
require 'json'

Excon.ssl_verify_peer = false

module GhostReader
  class NewClient

    attr_accessor :config, :last_modified

    def initialize(conf=nil)
      self.config = OpenStruct.new(default_config.merge(conf || {}))
    end

    # returns a Head with three keys
    #   :timestamp (the value of last-modified header)
    #   :data (a nested Hash of translations)
    #   :status (the reponse status)
    def initial_request
      response = service.get
      self.last_modified = response.get_header('Last-Modified')
      { :status => response.status,
        :data => JSON.parse(response.body) }
    end

    # returns true if redirected, false otherwise
    def reporting_request(data)
      { :status => service.post(:body => "data=#{data.to_json}").status }
    end

    # returns a Head with three keys
    #   :timestamp (the value of last-modified header)
    #   :data (a nested Hash of translations)
    #   :status (the reponse status)
    def incremental_request
      headers = { 'If-Modified-Since' => self.last_modified }
      response = service.get(:headers => headers)
      self.last_modified = response.get_header('Last-Modified')
      { :status => response.status }.tap do |result|
        result[:data] = JSON.parse(response.body) if response.status == 200
      end
    end

    private

    def address
      raise 'no api_key provided' if config.api_key.nil?
      @address ||= config.uri.sub(':api_key', config.api_key)
    end

    def service
      @service ||= Excon.new(address)
    end
    
    def default_config
      {
        :uri => 'http://ghost.panter.ch/api/:api_key/translations.json',
        :api_key => nil
      }
    end

  end
end
