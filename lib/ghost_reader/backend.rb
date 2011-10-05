module GhostReader

  class Backend
    include I18n::Backend::Simple::Implementation

    def initialize(url, opts={}, &block)
      @url=url
      @default_backend = opts[:default_backend]
      #@wait_time=opts[:wait_time] || 30
      #@max_packet_size=opts[:max_packet_size] || 100
      #@trace=opts[:trace]

      # Initialize the client
      @client = Client.new(url, opts)
    end

    def push_all_backend_data
      @client.wait_bg_thread()
      unless @default_backend && @default_backend.respond_to?(:get_all_data)
        puts "Default Backend not support reading all Data"
        return
      end
      miss_data={}

      @default_backend.get_all_data.each_pair do |locale, entries|
        collect_backend_data(entries, locale, [], miss_data)
      end
      last_res = @client.call_put_on_ghostwriter({}, miss_data)
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

    def lookup(locale, key, scope = [], options = {})
      init_translations unless initialized?
      @client.call_server

      keys = I18n.normalize_keys(locale, key, scope, options[:separator])
      filtered_options=options.reject { |key, value| key.to_sym==:scope }
      full_key=keys[1, keys.length-1].join('.')
      lookup_key(locale, keys, full_key, filtered_options)
    end

    def available_locales
      init_translations unless initialized?
      @client.call_server
      locales=[]
      if @default_backend
        locales.concat @default_backend.available_locales
      end
      if @client.store
        locales.concat @client.store.keys
      end
      locales.uniq
    end

    protected

    def lookup_key(locale, keys, full_key, filtered_options)
      found_value=keys.inject(@client.store) do |result, _key|
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
        if default_values && default_values.is_a?(Hash)
          found_value=default_values.deep_merge(found_value)
          inc_miss locale.to_s, full_key.to_s, filtered_options
        end
      end
      inc_hit full_key.to_s, filtered_options
      found_value
    end

    # counts a hit to a key
    def inc_hit(key, options)
      if @client.hits[key]
        @client.hits[key]+=1
      else
        @client.hits[key]=1
      end
    end

    # counts a miss to a key and a locale
    def inc_miss(locale, key, options)
      if @client.misses[key]
        key_hash = @client.misses[key]
      else
        key_hash={}
        @client.misses[key]=key_hash
      end
      if (key_hash[locale])
        key_hash[locale]+=1
      else
        key_hash[locale]=1
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
        found_value=key.split(/\./).inject(@client.store[available_locale]) do |result, _key|
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
