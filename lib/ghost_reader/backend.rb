require 'logger'
require 'ostruct'
require 'i18n'

module GhostReader
  class Backend

    module Implementation

      attr_accessor :config, :missings

      # exposed for testing & debugging
      attr_reader :retriever, :reporter

      # for options see code of default_config
      def initialize(conf={})
        self.config = OpenStruct.new(default_config.merge(conf))
        yield(config) if block_given?
        config.logger = Logger.new(config.logfile || STDOUT)
        config.logger.level = config.log_level || Logger::WARN
        config.service[:logger] ||= config.logger
        config.client ||= Client.new(config.service)
        unless config.no_auto_spawn
          log "GhostReader spawning agents."
          spawn_retriever
          spawn_reporter
          log "GhostReader spawned its agents."
        end
        log "Initialized GhostReader backend.", :info
      end

      def available_locales
        ( memoized_lookup.keys + config.fallback.available_locales ).uniq
      end

      protected

      # this won't be called if memoize kicks in
      def lookup(locale, key, scope = [], options = {})
        raise 'no fallback given' if config.fallback.nil?
        log "lookup: #{locale} #{key} #{scope.inspect} #{options.inspect}"
        
        result = config.fallback.translate(locale, key, options)
        log "fallback result: #{result.inspect}"
        return result
      rescue Exception => ex
        log "fallback.translate raised exception: #{ex}"
      ensure # make sure everything is tracked
        # TODO results which are hashes need to be tracked disaggregated
        track({ key => { locale.to_s => { 'default' => result } } }) unless result.is_a?(Hash)
        ex.nil? ? result : raise(ex)
      end

      def track(missing)
        return if missings.nil? # not yet initialized
        log "tracking: #{missing.inspect}"
        self.missings.deep_merge!(missing)
        log "missings: #{missings.inspect}"
      end

      # data, e.g. {'en' => {'this' => {'is' => {'a' => {'test' => 'This is a test.'}}}}}
      def memoize_merge!(data, options={ :method => :merge! })
        flattend = flatten_translations_for_all_locales(data)
        symbolized_flattend = symbolize_keys(flattend)
        memoized_lookup.send(options[:method], symbolized_flattend)
      end

      # performs initial and incremental requests
      def spawn_retriever
        log "Spawning retriever."
        @retriever = Thread.new do
          begin
            log "Performing initial request."
            response = config.client.initial_request
            memoize_merge! response[:data]
            self.missings = {} # initialized
            log "Initial request successfull.", :info
            until false
              begin
                sleep config.retrieval_interval
                response = config.client.incremental_request
                if response[:status] == 200
                  log "Incremental request with data.", :info
                  log "Data: #{response[:data].inspect}"
                  memoize_merge! response[:data], :method => :deep_merge!
                else
                  log "Incremental request, but no data."
                end
              rescue => ex
                log "Exception in retriever loop: #{ex}", :error
                log ex.backtrace.join("\n")
              end
            end
          rescue => ex
            log "Exception in retriever thread: #{ex}", :error
            log ex.backtrace.join("\n")
          end
        end
      end

      # performs reporting requests
      def spawn_reporter
        log "Spawning reporter."
        @reporter = Thread.new do
          until false
            begin
              sleep config.report_interval
              unless self.missings.nil?
                unless self.missings.empty?
                  log "Reporting request with % missings." % self.missings.keys.size, :info
                  config.client.reporting_request(missings)
                  missings.clear
                else
                  log "Reporting request omitted, nothing to report."
                end
              else
                log "Reporting request omitted, not yet initialized," +
                  " waiting for intial request."
              end
            rescue => ex
              log "Exception in reporter thread: #{ex}", :error
              log ex.backtrace.join("\n")
            end
          end
        end
      end

      # a wrapper for I18n::Backend::Flatten#flatten_translations
      def flatten_translations_for_all_locales(data)
        data.inject({}) do |result, key_value|
          begin
            key, value = key_value
            result.merge key => flatten_translations(key, value, true, false)
          rescue ArgumentError => ae
            log "Error: #{ae}", :error
            result
          end
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
          # see http://www.ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html
          :log_level => nil, # Log levels: FATAL, ERROR, WARN, INFO and DEBUG
          :service => {} # nested hash, see GhostReader::Client#default_config
        }
      end

      def log(msg, level=:debug)
        config.logger.send(level, "[#{$$}] #{msg}")
      end

    end

    include I18n::Backend::Base
    include Implementation
    include I18n::Backend::Memoize # provides #memoized_lookup
    include I18n::Backend::Flatten # provides #flatten_translations
  end
end

