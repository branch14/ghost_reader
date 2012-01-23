require 'excon'
require 'yaml'

module GhostReader
  module Util
    class << self

      def poll(headers={})
        return unless File.exist?(config_file)
        headers['If-Modified-Since'] = File.mtime(translation_file) if File.exist?(translation_file)
        headers.reverse_merge! :method => :get
        excon = Excon.new(config['static'])
        response = excon.request(headers)
        if response.status == 200
          translation_file response.body
          passenger_restart!
        end
      end

      def translation_file(content=nil)
        path = File.join(Rails.root, 'config', 'locales', 'ghost_reader.yml')
        return path if content.nil?
        File.open(path, 'w') { |f| f.puts content }
      end

      def config_file
        File.join(Rails.root, 'config', 'ghost_reader.yml')
      end

      def passenger_restart!
        FileUtils.touch(File.join(Rails.root, 'tmp', 'restart.txt'))
      end

      def config
        YAML.load(File.read(config_file))
      end

    end
  end
end
