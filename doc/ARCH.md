Client
======

    class Client
    
      # returns a Head with three keys
      #   :timestamp (the value of last-modified header)
      #   :data (a nested Hash of translations)
      #   :status (the reponse status)
      def initial_request
      end
    
      # returns true if redirected, false otherwise
      def reporting_request(data)
      end
    
      # returns a Head with three keys
      #   :timestamp (the value of last-modified header)
      #   :data (a nested Hash of translations)
      #   :status (the reponse status)
      def incremental_request
      end
    
    end

Initializer
===========

    options = {
      :host => '',
      :update_interval => 1.minute,
      :reset_interval => 15.minutes,
      :fallback => I18n.backend,
      :api_key => '91885ca9ec4feb9b2ed2423cdbdeda32'
    }
    I18n.backend = GhostReader::I18nBackend.new(options).start_agents

