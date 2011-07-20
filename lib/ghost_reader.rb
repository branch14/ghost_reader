require 'i18n'
require 'net/http'
require 'json'

module GhostReader
  class Backend
    include I18n::Backend::Simple::Implementation

    def initialize(url, opts={}, &block)
      @url=url
      @default_backend=opts[:default_backend]
      @wait_time=opts[:wait_time] || 30
      @max_packet_size=opts[:max_packet_size] || 100
      @trace=opts[:trace]
      @hits={}
      @misses={}
      @last_server_call=0
        # initiates first call for filling caches in background
      if defined?(PhusionPassenger)
        # In Passenger load data in foreground
        @store=load_yaml_from_ghostwriter
      else
        # Elsewhere load data in Background
        call_server
      end
    end

      # Add a new default value
    def add_default_value(miss_data, available_locale, key, default_value,
            count_data)
      if default_value.is_a?(Hash)
        default_value.each_pair do |entry_key, entry_value|
          add_default_value(miss_data, available_locale,
                            "#{key}.#{entry_key}", entry_value,
                            count_data)
        end
      else
        found_value=key.split(/\./).inject(@store[available_locale]) do |result, _key|
          unless result.nil?
            _key = _key.to_sym
            result = result[_key]
            result
          end
        end
        if found_value.nil?
          key_result = miss_data[key.to_s]
          if key_result.nil?
            key_result={:count=>count_data, :default=>{}}
            miss_data[key.to_s]=key_result
          end
          key_result[:default][available_locale]=default_value
        end
      end
    end

      # calculates data about cache-miss for server
    def calc_miss_data(misses)
      miss_data={}
      misses.each_pair do |key, key_data|
        key_result={}
        count_data={}
        key_data.each_pair do |locale, count|
          count_data[locale.to_sym]=count
        end
        count_added=false
        if @default_backend
          default_data={}
          @default_backend.available_locales.each do |available_locale|
            default_value = @default_backend.lookup available_locale, key
            unless default_value.nil?
              count_added=true
              add_default_value(miss_data, available_locale,
                                key, default_value, count_data)
            end
          end
#          key_result[:default]=default_data unless default_data.empty?
        end
        if not count_added
          key_result[:count]=count_data
          miss_data[key]=key_result
        end
      end
      miss_data
    end

    def collect_hit_values(key, value, count)
      if value.is_a? Hash
        ret={}
        value.each_pair do |entry_key, entry_value|
          ret.merge!(collect_hit_values("#{key}.#{entry_key}", entry_value,
                                        count))
        end
        return ret
      else
        return {key=>count}
      end
    end

      # distribute hit-data down to single keys
    def calc_hit_data(hits)
      return hits if @store.nil?
      merged_languages=@store.keys.inject({}) do |result, key|
        result=result.deep_merge(@store[key])
        result
      end
      hit_data={}
      hits.each_pair do |key, hit_count|
        found_value=key.split(/\./).inject(merged_languages) do |result, _key|
          unless result.nil?
            _key = _key.to_sym
            result = result[_key]
            result
          end
        end
        hit_data.merge! collect_hit_values key, found_value,
                                           hit_count unless found_value.nil?
      end
      hit_data
    end

    def load_yaml_from_ghostwriter
      response = call_get_on_ghostwriter
      case response
        when Net::HTTPSuccess
          return YAML.load(response.body.to_s)
      end
      {}
    end

    def call_get_on_ghostwriter
      url=URI.parse(@url)
      req=Net::HTTP::Get.new(url.path)
      req['If-Modified-Since']=@last_version if @last_version
      log "Get start"
      res = Net::HTTP.new(url.host, url.port).start do |http|
        http.request(req)
      end
      log "Get returned with #{res.code}"
      res
    end

    def call_put_on_ghostwriter(hits, miss_data)
      res=nil
      while (hits.size>0 || miss_data.size>0) &&
              (res==nil ||
                      res.kind_of?(Net::HTTPSuccess)||
                      res.kind_of?(Net::HTTPNotModified))
        call_entry_count=0
        part_hits={}
        part_miss={}
        while (call_entry_count<@max_packet_size && hits.size>0)
          entry=hits.shift
          part_hits[entry[0]]=entry[1]
          call_entry_count+=1
        end
        while (call_entry_count<@max_packet_size && miss_data.size>0)
          entry=miss_data.shift
          part_miss[entry[0]]=entry[1]
          call_entry_count+=1
        end
        url=URI.parse(@url)
        req=Net::HTTP::Post.new(url.path)
        req['If-Modified-Since']=@last_version
        req.set_form_data({:hits=>part_hits.to_json,
                           :miss=>part_miss.to_json})
        log "Post start"
        res = Net::HTTP.new(url.host, url.port).start do |http|
          http.request(req)
        end
        log "Post returned with #{res.code}"
      end
      res
    end

    def push_all_backend_data
      unless @default_backend && @default_backend.respond_to?(:get_all_data)
        puts "Default Backend not support reading all Data"
        return
      end
      miss_data={}

      @default_backend.get_all_data.each_pair do |locale, entries|
        collect_backend_data(entries, locale, [], miss_data)
      end
      last_res=call_put_on_ghostwriter({}, miss_data)
      unless (last_res.kind_of?(Net::HTTPSuccess) ||
              last_res.kind_of?(Net::HTTPNotModified))
        puts "Unexpected Answer from Server"
        puts "#{last_res.code}: #{last_res.message}"
      end
    end

    def collect_backend_data(entries, locale, base_chain, miss_data)
      entries.each_pair do |key, sub_entries|
        key_data=[base_chain, [key.to_s]].flatten
        case sub_entries
          when String
            key_string=key_data.join '.'
            key_data=miss_data[key_string]
            unless key_data
              key_data={'default'=>{}, 'count'=>{}}
              miss_data[key_string]=key_data
            end
            key_data['default'][locale.to_s]=sub_entries
          when Hash
            collect_backend_data sub_entries, locale, key_data, miss_data
        end
      end
    end

      # contact server and exchange data if last call is more than @wait_time
      #seconds
    def call_server
      if @bg_thread
        # dont start more than one background_thread
        return if @bg_thread.alive?
        # get the values from the last call
        if @bg_thread[:store]
          @store=@bg_thread[:store]
          @last_version=@bg_thread[:last_version]
        end
        @bg_thread = nil
        #return
      end
      return if Time.now.to_i-@last_server_call<@wait_time

      # take the needed Values and give it to the thread
      misses=@misses
      hits=@hits
        # make new empty values for collecting statistics
      @hits={}
      @misses={}
      @last_server_call=Time.now.to_i

      @bg_thread=Thread.new(misses, hits) do
        begin
          miss_data = calc_miss_data(misses)
          hit_data = calc_hit_data(hits)

          if miss_data.size>0 || hit_data.size>0
            res = call_put_on_ghostwriter(hit_data, miss_data)
          else
            res = call_get_on_ghostwriter()
          end
          case res
            when Net::HTTPSuccess
              Thread.current[:store]=YAML.load(res.body.to_s).deep_symbolize_keys
              Thread.current[:last_version]=res["last-modified"]
          end
        rescue Object => ex
          puts "Exception ============\n#{ex.inspect}\n========================\n"
        end
      end

    end

      # counts a hit to a key
    def inc_hit(key, options)
      if @hits[key]
        @hits[key]+=1
      else
        @hits[key]=1
      end
    end

      # counts a miss to a key and a locale
    def inc_miss(locale, key, options)
      if @misses[key]
        key_hash=@misses[key]
      else
        key_hash={}
        @misses[key]=key_hash
      end
      if (key_hash[locale])
        key_hash[locale]+=1
      else
        key_hash[locale]=1
      end
    end

    def lookup(locale, key, scope = [], options = {})
      init_translations unless initialized?
      call_server

      keys = I18n.normalize_keys(locale, key, scope, options[:separator])
      filtered_options=options.reject { |key, value| key.to_sym==:scope }
      full_key=keys[1, keys.length-1].join('.')
      lookup_key(locale, keys, full_key, filtered_options)
    end

    def lookup_key(locale, keys, full_key, filtered_options)
      found_value=keys.inject(@store) do |result, _key|
        _key = _key.to_sym
        unless result.is_a?(Hash) && result.has_key?(_key)
          inc_miss locale.to_s, full_key.to_s, filtered_options
          return @default_backend.lookup locale, full_key
        end
        result = result[_key]
        result
      end
      if found_value.is_a? Hash
        default_values = @default_backend.lookup(locale, full_key)
        if default_values
          found_value=default_values.deep_merge(found_value)
          inc_miss locale.to_s, full_key.to_s, filtered_options
        end
      end
      inc_hit full_key.to_s, filtered_options
      found_value
    end

    def available_locales
      init_translations unless initialized?
      call_server
      locales=[]
      if @default_backend
        locales.concat @default_backend.available_locales
      end
      if @store
        locales.concat @store.keys
      end
      locales.uniq
    end
    # Simple logs messages to console if enabled
    def log(message)
      if @trace
        #@trace.call "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}: #{message}"
        @trace.call message
      end
    end

  end
  if defined?(Rails)
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load "tasks/ghost_reader.rake"
      end
    end
  end

  ::I18n::Backend::Simple::Implementation.module_eval do
    def get_all_data
      available_locales
      translations
    end
  end
end
