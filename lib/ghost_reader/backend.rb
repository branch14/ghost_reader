require 'logger'
require 'ostruct'
require 'i18n/backend/transliterator' # i18n/backend/base fails to require this
require 'i18n/backend/base'
require 'i18n/backend/memoize'
require 'i18n/backend/flatten'

module GhostReader
  class Backend
    module Implementation

      attr_accessor :config, :missings

      # for options see code of default_config
      def initialize(conf={})
        self.config = OpenStruct.new(default_config.merge(conf))
        yield(config) if block_given?
        config.logger = Logger.new(config.logfile || STDOUT)
        config.service[:logger] ||= config.logger
        config.client = Client.new(config.service)
        config.logger.debug "Initialized backend."
      end

      def spawn_agents
        config.logger.debug "Spawning agents."
        spawn_retriever
        spawn_reporter
        config.logger.debug "Spawned its agents."
        self
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
        return if self.missings.nil? # not yet initialized
        self.missings.deep_merge!(missings)
      end

      # performs initial and incremental requests
      def spawn_retriever
        config.logger.debug "Spawning retriever."
        Thread.new do
          config.logger.debug "Performing initial request."
          result = config.client.initial_request
          @memoized_lookup = flatten_translations_for_all_locales(result[:data])
          self.missings = {} # initialized
          config.logger.debug "Initial request successfull."
          until false
            sleep config.retrieval_interval
            response = config.client.incremental_request
            if response[:status] == 200
              config.logger.debug "Incremental request with data."
              flattend = flatten_translations_for_all_locales(response[:data])
              @memoized_lookup.deep_merge! flattend
            else
              config.logger.debug "Incremental request, but no data."
            end
          end
        end
      end

      # performs reporting requests
      def spawn_reporter
        config.logger.debug "Spawning reporter."
        Thread.new do
          until false
            sleep config.report_interval
            unless self.missings.empty?
              config.logger.debug "Reporting request with #{self.missings.keys.size} missings."
              config.client.reporting_request(missings)
              missings.clear
            else
              config.logger.debug "Reporting request omitted, nothing to report."
            end
          end
        end
      end

      # a wrapper for I18n::Backend::Flatten#flatten_translations
      def flatten_translations_for_all_locales(data)
        data.inject({}) do |result, key_value|
          key, value = key_value
          result.merge key => flatten_translations(key, value, true, false)
        end
      end

      def default_config
        {
          :retrieval_interval => 15,
          :report_interval => 10,
          :fallback => nil, # a I18n::Backend (mandatory)
          :logfile => nil, # a path
          :service => {} # nested hash, see GhostReader::Client#default_config
        }
      end
    end

    include I18n::Backend::Base
    include Implementation
    include I18n::Backend::Memoize # provides @memoized_lookup
    include I18n::Backend::Flatten # provides #flatten_translations
  end
end
