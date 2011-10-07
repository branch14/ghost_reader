require 'logger'
require 'ostruct'
require 'i18n/backend/transliterator' # i18n/backend/base fails to require this
require 'i18n/backend/base'
require 'i18n/backend/memoize'
require 'i18n/backend/flatten'

module GhostReader
  class Backend

    module DebugLookup
      def lookup(*args)
        config.logger.debug "Lookup: #{args.inspect}"
        # debugger
        super
      end
    end

    module Implementation

      attr_accessor :config, :missings

      # for options see code of default_config
      def initialize(conf={})
        self.config = OpenStruct.new(default_config.merge(conf))
        yield(config) if block_given?
        config.logger = Logger.new(config.logfile || STDOUT)
        config.logger.level = config.log_level || Logger::WARN
        config.service[:logger] ||= config.logger
        config.client = Client.new(config.service)
        config.logger.info "Initialized GhostReader backend."
      end

      def spawn_agents
        config.logger.debug "GhostReader spawning agents."
        spawn_retriever
        spawn_reporter
        config.logger.debug "GhostReader spawned its agents."
        self
      end

      protected

      # this won't be called if memoize kicks in
      def lookup(locale, key, scope = [], options = {})
        raise 'no fallback given' if config.fallback.nil?
        config.fallback.translate(locale, key, options).tap do |result|
          # TODO results which are hashes need to be tracked disaggregated
          track({ key => { locale => { 'default' => result } } }) unless result.is_a?(Hash)
        end
      end

      def track(missings)
        return if self.missings.nil? # not yet initialized
        self.missings.deep_merge!(missings)
      end

      def memoize_merge!(data, options={ :method => :merge! })
        flattend = flatten_translations_for_all_locales(data)
        symbolized_flattend = symbolize_keys(flattend)
        memoized_lookup.send(options[:method], symbolized_flattend)
      end

      # performs initial and incremental requests
      def spawn_retriever
        config.logger.debug "Spawning retriever."
        Thread.new do
          begin
            config.logger.debug "Performing initial request."
            response = config.client.initial_request
            memoize_merge! response[:data]
            self.missings = {} # initialized
            config.logger.info "Initial request successfull."
            until false
              sleep config.retrieval_interval
              response = config.client.incremental_request
              if response[:status] == 200
                config.logger.info "Incremental request with data."
                memoize_merge! response[:data], :method => :deep_merge!
              else
                config.logger.debug "Incremental request, but no data."
              end
            end
          rescue => ex
            config.logger.error "Exception in retriever thread: #{ex}"
          end
        end
      end

      # performs reporting requests
      def spawn_reporter
        config.logger.debug "Spawning reporter."
        Thread.new do
          begin
            until false
              sleep config.report_interval
              unless self.missings.nil?
                unless self.missings.empty?
                  config.logger.info "Reporting request with #{self.missings.keys.size} missings."
                  config.client.reporting_request(missings)
                  missings.clear
                else
                  config.logger.debug "Reporting request omitted, nothing to report."
                end
              else
                config.logger.debug "Reporting request omitted, not yet initialized, waiting for intial request."
              end
            end
            config.logger.error "Reporter finished."
          rescue => ex
            config.logger.error "Exception in reporter thread: #{ex}"
            config.logger.error e.backtrace
            puts e.backtrace
            config.logger.error '-'*60
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

      def symbolize_keys(hash)
        hash.each.inject({}) do |symbolized_hash, key_value|
          key, value = key_value
          symbolized_hash.merge!({key.to_sym, value})
        end
      end

      def default_config
        {
          :retrieval_interval => 15,
          :report_interval => 10,
          :fallback => nil, # a I18n::Backend (mandatory)
          :logfile => nil, # a path
          :log_level => nil, # Log level, the options are Config::(FATAL, ERROR, WARN, INFO and DEBUG)           (http://www.ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html)
          :service => {} # nested hash, see GhostReader::Client#default_config
        }
      end
    end

    include I18n::Backend::Base
    include Implementation
    include I18n::Backend::Memoize # provides @memoized_lookup
    include I18n::Backend::Flatten # provides #flatten_translations
    include DebugLookup
  end
end

