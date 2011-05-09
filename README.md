GhostReader
===========

i18n backend to ghost_writer service

### Usage

add a folowing to 'config/initializers/ghost_reader.rb'

    I18n.backend=I18n::Backend::Chain.new(
            GhostReader::Backend.new("HTTP_URL_TO_GHOST_SERVER", I18n.backend),
            I18n.backend)
