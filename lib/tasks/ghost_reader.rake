namespace :ghost_reader do

  desc "Fetch newest translations from ghost-writer and overwrite the local translations"
  task :fetch => :environment do
    unless I18n.backend.respond_to? :load_yaml_from_ghostwriter
      raise "ERROR: Ghostwriter is not configured as I18n.backend"
    end

    begin
      puts "Loading data from Ghostwriter and delete old translations"
      yaml_data = I18n.backend.load_yaml_from_ghostwriter
    rescue Exception => e
      abort e.message
    end

    yaml_data.each_pair do |key,value|
      outfile = Rails.root.join("config", "locales",
                                "#{key.to_s}.yml")
      begin
        puts "Deleting old translations: #{outfile}"
        File.delete(outfile) if File.exists?(outfile)
      rescue Exception => e
        abort "Couldn't delete file: #{e.message}"
      end

      begin
        puts "Writing new translations: #{outfile}"
        File.open(outfile, "w") do |yaml_file|
          yaml_file.write({key => value}.to_yaml)
        end
      rescue Exception => e
        abort "Couldn't write file: #{e.message}"
      end
    end
  end

  desc "Push all locally configured translations to ghost-writer"
  task :push => :environment do
    unless I18n.backend.respond_to? :push_all_backend_data
      raise "ERROR: Ghostwriter is not configured as I18n.backend"
    end
    puts "Pushing data to Ghostwriter"
    begin
      I18n.backend.push_all_backend_data
    rescue Exception => e
      abort e.message
    end
  end

  desc "Install default initializer for ghost reader"
  task :install => :environment do

    # TODO: this should only when the ghost_reader is introduced as gem
    infile = 'templates/ghost_reader.rb'
    outdir = Rails.root.join("config", "initializers")

    puts "Installing ghost_reader.rb initializer..."
    FileUtils.copy_file(infile, outdir)
    puts "Done."
  end

end
