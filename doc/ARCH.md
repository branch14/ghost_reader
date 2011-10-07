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


Custom Initializer for Development
==================================

    require File.expand_path(File.join(%w(.. .. .. .. ghost_reader lib ghost_reader)), __FILE__)
    
    config = {
      :report_interval => 5, # secs
      :retrieval_interval => 10, # secs
      :fallback => I18n.backend,
      :logfile => File.join(Rails.root, %w(log ghostwriter.log)),
      :service => {
        :api_key => '9d07cf6d805ea2951383c9ed76db762e' # Ghost Dummy Project
      }
    }
    
    I18n.backend = GhostReader::Backend.new(config).spawn_agents
