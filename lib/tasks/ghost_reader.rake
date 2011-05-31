
namespace :ghost_reader do
  desc "Fetch newest translations from ghost-writer and overwrite the local translations"
  task :fetch => :environment do
    unless I18n.backend.respond_to? :load_yaml_from_ghostwriter
      raise "ERROR: Ghostwriter is not configured as I18n.backend"
    end
    Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')].each do |file|
      puts "Removing #{file}"
      File.delete(file)
    end
    puts "Loading data from Ghostwriter"
    yaml_data = I18n.backend.load_yaml_from_ghostwriter
    yaml_data.each_pair do |key,value|
      outfile = Rails.root.join("config", "locales",
                                "ghost_writer-#{key.to_s}.yml")
      puts "Writing #{outfile}"
      File.open(outfile, "w") do |yaml_file|
        yaml_file.write({key => value}.to_yaml)
      end
    end
  end
end
