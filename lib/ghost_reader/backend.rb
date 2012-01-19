require 'logger'
require 'ostruct'
require 'i18n'

module GhostReader
  class Backend

    module Implementation

      attr_accessor :config, :missings

      # for options see code of default_config
      def initialize(conf={})
        self.config = OpenStruct.new(default_config.merge(conf))
        yield(config) if block_given?
        config.logger = Logger.new(config.logfile || STDOUT)
        config.logger.level = config.log_level || Logger::WARN
        config.service[:logger] ||= config.logger
        config.client ||= Client.new(config.service)
        @report_ts = @retrieval_ts = Time.now
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
        
        result = config.fallback.lookup(locale, key, scope, options)
        log "fallback result: #{result.inspect}"
      rescue Exception => ex
        log "fallback.lookup raised exception: #{ex}"
      ensure # make sure everything is tracked
        # TODO results which are hashes need to be tracked disaggregated
        track({ key => { locale.to_s => { 'default' => result } } }) unless result.is_a?(Hash)
        report_and_retrieve
        raise(ex) unless ex.nil?
        return result
      end

      def track(missing)
        return if missings.nil? # not yet initialized
        log "tracking: #{missing.inspect}"
        self.missings.deep_merge!(missing)
        log "# of missings: #{missings.keys.size}"
      end

      def report_and_retrieve
        initialize_retrieval if missings.nil?
        diff = Time.now - @report_ts
        if diff > config.report_interval
          threadify do
            log "Kick off report. #{missings.inspect}"
            @report_ts = Time.now
            report
            @report_ts = Time.now
          end
        else
          log "Skipping report. #{diff}"
        end

        diff = Time.now - @retrieval_ts
        if diff > config.retrieval_interval
          threadify do
            log "Kick off retrieval."
            @retrieval_ts = Time.now
            retrieve
            @retrieval_ts = Time.now
          end
        else
          log "Skipping retrieval. #{diff}"
        end
      end

      def threadify(&block)
        if config.no_threads
          block.call
        else
          Thread.new { block.call }
        end
      end

      # data, e.g. {'en' => {'this' => {'is' => {'a' => {'test' => 'This is a test.'}}}}}
      def memoize_merge!(data, options={ :method => :merge! })
        flattend = flatten_translations_for_all_locales(data)
        symbolized_flattend = symbolize_keys(flattend)
        memoized_lookup.send(options[:method], symbolized_flattend)
      end

      def initialize_retrieval
        log "Performing initial request."
        response = config.client.initial_request
        memoize_merge! response[:data]
        self.missings = {} # initialized                                                              
        log "Initial request successfull.", :info
      rescue => ex
        log "Exception initializing retrieval: #{ex}", :error
        log ex.backtrace.join("\n"), :error
      end

      def retrieve
        response = config.client.incremental_request
        if response[:status] == 200
          log "Incremental request with data.", :info
          log "Data: #{response[:data].inspect}"
          memoize_merge! response[:data], :method => :deep_merge!
        else
          log "Incremental request, but no data.", :info
        end
      rescue => ex
        log "Exception in retrieval: #{ex}", :error
        log ex.backtrace.join("\n"), :error
      end

      def report
        unless self.missings.nil?
          unless self.missings.empty?
            log "Reporting request with #{self.missings.keys.size} missings.", :info
            config.client.reporting_request(missings)
            self.missings.clear
            log "Missings emptied."
          else
            log "Reporting request omitted, nothing to report."
          end
        else
          log "Reporting request omitted, not yet initialized," +
            " waiting for intial request."
        end
      rescue => ex
        log "Exception in report: #{ex}", :error
        log ex.backtrace.join("\n")
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

