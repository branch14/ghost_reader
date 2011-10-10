# NOTE: We won't need this probably because the ghost_reader will be loaded as a gem
# require File.expand_path(File.join(%w(.. .. .. .. ghost_reader lib ghost_reader)), __FILE__)

config = {
  :report_interval => 5, # secs
  :retrieval_interval => 10, # secs
  :fallback => I18n.backend,
  :logfile => File.join(Rails.root, %w(log ghostwriter.log)),
  :service => {
    :api_key => '9d07cf6d805ea2951383c9ed76db762e' # Ghost Dummy Project
  }
}

I18n.backend = GhostReader::Backend.new(config)
