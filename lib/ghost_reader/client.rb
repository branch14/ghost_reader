require 'excon'
require 'json'

module GhostReader
  class Client

    def initialize(config)
      @uri = config[:uri]
    end

    def initial_request
      build_response(Excon.get(@uri))
    end

    private

    def build_response(excon_response)
      { :status => excon_response.status,
        :data => excon_response.body,
        :timestamp => excon_response.headers["last-modified"] }
    end

#    attr_accessor :hits, :misses, :store

    #def initialize(url, opts)
      #@url = url
      #@wait_time = opts[:wait_time] || 30
      #@max_packet_size = opts[:max_packet_size] || 100
      #@trace = opts[:trace]
      #@last_server_call = 0

      #@hits = {}
      #@misses = {}

      #@store = call_server
    #end

    #def load_yaml_from_ghostwriter
      #wait_bg_thread()
      #response = call_get_on_ghostwriter
      #case response
        #when Net::HTTPSuccess
          #return YAML.load(response.body.to_s)
      #end
      #{}
    #end

    #def call_get_on_ghostwriter
      #url=URI.parse(@url)
      #req=Net::HTTP::Get.new(url.path)
      #req['If-Modified-Since']=@last_version if @last_version
      #log "Get start"
      #res = Net::HTTP.new(url.host, url.port).start do |http|
        #http.request(req)
      #end
      #log "Get returned with #{res.code}"
      #res
    #end

    #def call_put_on_ghostwriter(hits, miss_data)
      #res=nil
      #while (hits.size>0 || miss_data.size>0) &&
              #(res==nil ||
                      #res.kind_of?(Net::HTTPSuccess)||
                      #res.kind_of?(Net::HTTPNotModified))
        #call_entry_count=0
        #part_hits={}
        #part_miss={}
        #while (call_entry_count<@max_packet_size && hits.size>0)
          #entry=hits.shift
          #part_hits[entry[0]]=entry[1]
          #call_entry_count+=1
        #end
        #while (call_entry_count<@max_packet_size && miss_data.size>0)
          #entry=miss_data.shift
          #part_miss[entry[0]]=entry[1]
          #call_entry_count+=1
        #end
        #url=URI.parse(@url)
        #req=Net::HTTP::Post.new(url.path)
        #req['If-Modified-Since']=@last_version
        #req.set_form_data({:hits=>part_hits.to_json,
                           #:miss=>part_miss.to_json})
        #log "Post start"
        #res = Net::HTTP.new(url.host, url.port).start do |http|
          #http.request(req)
        #end
        #log "Post returned with #{res.code}"
      #end
      #res
    #end

    ## contact server and exchange data if last call is more than @wait_time
    ## seconds
    #def call_server
      #if @bg_thread
        ## dont start more than one background_thread
        #return if @bg_thread.alive?
          ## get the values from the last call
        #if @bg_thread[:store]
          #@store = @bg_thread[:store]
          #@last_version = @bg_thread[:last_version]
          #log "New data from Server activated"
        #end
        #@bg_thread = nil
        ##return
      #end
      #return if Time.now.to_i - @last_server_call < @wait_time

      ## take the needed Values and give it to the thread
      #current_misses = @misses
      #current_hits = @hits

      ## make new empty values for collecting statistics
      #@hits={}
      #@misses={}
      #@last_server_call=Time.now.to_i
      #@bg_thread=Thread.new(current_misses, current_hits) do
        #begin
          #miss_data = calc_miss_data(current_misses)
          #hit_data = calc_hit_data(current_hits)

          #if miss_data.size>0 || hit_data.size>0
            #res = call_put_on_ghostwriter(hit_data, miss_data)
          #else
            #res = call_get_on_ghostwriter()
          #end
          #case res
            #when Net::HTTPSuccess
              #Thread.current[:store]=YAML.load(res.body.to_s).deep_symbolize_keys
              #Thread.current[:last_version]=res["last-modified"]
          #end
        #rescue Object => ex
          #puts "Exception ============\n#{ex.inspect}\n========================\n"
        #end
      #end
    #end

    ## distribute hit-data down to single keys
    #def calc_hit_data(hits)
      #return hits if @store.nil?
      #merged_languages=@store.keys.inject({}) do |result, key|
        #result=result.deep_merge(@store[key])
        #result
      #end
      #hit_data={}
      #hits.each_pair do |key, hit_count|
        #found_value=key.split(/\./).inject(merged_languages) do |result, _key|
          #unless result.nil?
            #_key = _key.to_sym
            #result = result[_key]
            #result
          #end
        #end
        #hit_data.merge! collect_hit_values key, found_value,
                                           #hit_count unless found_value.nil?
      #end
      #hit_data
    #end



    ## calculates data about cache-miss for server
    #def calc_miss_data(misses)
      #miss_data={}
      #misses.each_pair do |key, key_data|
        #key_result={}
        #count_data={}
        #key_data.each_pair do |locale, count|
          #count_data[locale.to_sym]=count
        #end
        #count_added=false
        #if @default_backend
          #default_data={}
          #@default_backend.available_locales.each do |available_locale|
            #default_value = @default_backend.lookup available_locale, key
            #unless default_value.nil?
              #count_added=true
              #add_default_value(miss_data, available_locale,
                                #key, default_value, count_data)
            #end
          #end
        ## key_result[:default]=default_data unless default_data.empty?
        #end
        #if not count_added
          #key_result[:count]=count_data
          #miss_data[key]=key_result
        #end
      #end
      #miss_data
    #end

    #def collect_hit_values(key, value, count)
      #if value.is_a? Hash
        #ret={}
        #value.each_pair do |entry_key, entry_value|
          #ret.merge!(collect_hit_values("#{key}.#{entry_key}", entry_value,
                                        #count))
        #end
        #return ret
      #else
        #return {key=>count}
      #end
    #end

    ## TODO: dan: This should be protected?
    #def wait_bg_thread
      #bg_thread = @bg_thread
      #if bg_thread
        #bg_thread.join
      #end
    #end

    ## Simple logs messages to console if enabled
    #def log(message)
      #if @trace
        #@trace.call "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} [#{Thread.current}]: Ghost_Reader: #{message}"
      #end
    #end

  end
end
