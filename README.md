GhostReader
===========

i18n backend to ghost_writer service

## Usage

add a folowing to `config/initializers/ghost_reader.rb`

    I18n.backend=I18n::Backend::Chain.new(
            GhostReader::Backend.new("HTTP_URL_TO_GHOST_SERVER",
            :default_backend=>I18n.backend, :wait_time=>30),
            I18n.backend)

### wait_time
The 'wait_time' is the minimum time in seconds after which reached a change
from the Ghost_Writer Ghost_Client. A low value minimizes the delay,
a high value minimizes the network-traffic.
Default-Value is 30

### default_backend
The Ghost_reader tries to find default-values for not found translations and
posts them to the server together with the statistical data.