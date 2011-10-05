require 'i18n/backend/base'
require 'i18n/backend/memoize'
require 'ghost_reader/client'

module GhostReader

  class NewBackend
    include I18n::Backend::Base
    include I18n::Backend::Memoize # provides @memozied_lookup

    attr_accessor :config, :missings, :logger, :client
    
    # for options see code of default_config
    def initialize(config={})
      self.config = OpenStruct.new(default_config.merge(config))
      yield(self.config) if block_given?
      self.logger = Logger.new(config.logfile || STDOUT)
      self.client = Client.new(config)
      spawn_retiever
      spawn_reporter
    end

    protected

    # this won't be called if memoize kicks in
    def lookup(locale, key, scope = [], options = {})
      raise 'no fallback given' if config.fallback.nil?
      config.fallback.translate(locale, key, options).tap do |result|
        raise 'result is a hash' if result.is_a?(Hash) # TODO
        track({ key => { locale => { 'default' => result } } })
      end
    end

    def track(missings)
      return unless self.missings.nil? # not yet initialized
      self.missings.deep_merge!(missings)
    end

    # performs initial and incremental requests
    def spawn_retriever
      Thread.new do
        @memoized_lookup = client.initial_request[:data]
        self.missings = {} # initialized
        until false
          sleep config.retrieval_interval
          logger.debug "Incremental request."
          response = client.incremental_request
          @memoized_lookup.merge!(response[:data]) if response[:status] == 200
        end
      end
    end

    # performs reporting requests
    def spawn_reporter
      Thread.new do
        until false
          sleep config.report_interval
          unless self.missings.empty?
            logger.debug "Reporting request with #{self.missings.keys.size} missings."
            client.reporting_request(missings)
            missings.clear
          else
            logger.debug "Reporting request omitted, nothing to report."
          end
        end
      end
    end

    def default_config
      {
        :retrieval_interval => 15,
        :report_interval => 10,
        :uri => 'http://ghost.panter.ch/api/:api_key/translations.json',
        :fallback => nil,
        :api_key => nil,
        :logfile => nil
      }
    end

  end
end
