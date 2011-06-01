require 'i18n'
require 'net/http'
require 'json'

module GhostReader
  class Backend
    include I18n::Backend::Simple::Implementation

    def initialize(url, opts={})
      @url=url
      @default_backend=opts[:default_backend]
      @wait_time=opts[:wait_time] || 30
      @max_packet_size=opts[:max_packet_size] || 100
      @hits={}
      @misses={}
      @last_server_call=0
      # initiates first call for filling caches in background
      call_server
    end

    # calculates data about cache-miss for server
    def calc_miss_data(misses)
      miss_data={}
      misses.each_pair do |key, key_data|
        key_result={}
        miss_data[key]=key_result
        if @default_backend
          default_data={}
          @default_backend.available_locales.each do |available_locale|
            default_value = @default_backend.lookup available_locale, key
            default_data[available_locale]= default_value if default_value
          end
          key_result[:default]=default_data unless default_data.empty?
        end
        count_data={}
        key_result[:count]=count_data
        key_data.each_pair do |locale, count|
          count_data[locale.to_sym]=count
        end
      end
      miss_data
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
      res = Net::HTTP.new(url.host, url.port).start do |http|
        http.request(req)
      end
      res
    end

    def call_put_on_ghostwriter(hits, miss_data)
      res=nil
      while (hits.size>0 || miss_data.size>0) &&
              (res==nil ||
                      res.instance_of?(Net::HTTPSuccess)||
                      res.instance_of?(Net::HTTPNotModified))
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
        res = Net::HTTP.new(url.host, url.port).start do |http|
          http.request(req)
        end
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
      unless (last_res.instance_of?(Net::HTTPSuccess) ||
              last_res.instance_of?(Net::HTTPNotModified))
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
      if @bg_thread && (not @bg_thread.alive?)
        # get the values from the last call
        @store=@bg_thread[:store]
        @last_version=@bg_thread[:last_version]
        @bg_thread = nil
      end
      return if Time.now.to_i-@last_server_call<@wait_time

      # dont start more than one background_thread
      return if @bg_thread && @bg_thread.alive?
      # take the needed Values and give it to the thread
      misses=@misses
      hits=@hits
      # make new empty values for collecting statistics
      @hits={}
      @misses={}
      @last_server_call=Time.now.to_i

      @bg_thread=Thread.new(misses, hits) do
        miss_data = calc_miss_data(misses)

        if miss_data.size>0 || hits.size>0
          res = call_put_on_ghostwriter(hits, miss_data)
        else
          res = call_get_on_ghostwriter()
        end
        case res
          when Net::HTTPSuccess
            Thread.current[:store]=YAML.load(res.body.to_s).deep_symbolize_keys
            Thread.current[:last_version]=res["last-modified"]
        end
      end

    end

    # counts a hit to a key
    def inc_hit(key)
      if @hits[key]
        @hits[key]+=1
      else
        @hits[key]=1
      end
    end

    # counts a miss to a key and a locale
    def inc_miss(locale, key)
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
      full_key=keys[1, keys.length-1].join('.')

      found_value=keys.inject(@store) do |result, _key|
        _key = _key.to_sym
        unless result.is_a?(Hash) && result.has_key?(_key)
          inc_miss locale.to_s, full_key.to_s
          return @default_backend.lookup locale, full_key
        end
        result = result[_key]
        result
      end
      inc_hit full_key.to_s
      found_value
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
