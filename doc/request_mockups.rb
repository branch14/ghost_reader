require 'rubygems'
require 'excon'
require 'json'
require 'ruby-debug'

# Excon.ssl_verify_peer = false

host = '0.0.0.0:3001'
host = 'ghost.panter.ch'
api_key = '91885ca9ec4feb9b2ed2423cdbdeda32' # dummy local
api_key = 'e0e948efc3606e00c4b981bb2d3f7463' # CSP Live
address = "http://#{host}/api/#{api_key}/translations.json"
excon = Excon.new(address)
puts

puts "(1) Initial request... (GET without If-Modified-Since)"
response = excon.get
puts
puts "  Status:         #{response.status}"
puts "  Body size:      #{response.body.size}"
@last_modified = response.get_header('Last-Modified')
puts "  Last-Modified:  #{@last_modified}"
puts

puts "(2) Reporting request... (POST)"
data = {
  "sample.key_1" => {"en" => {"count" => 42, "default" => "Sample translation 1."}},
  "sample.key_2" => {"en" => {"count" => 23, "default" => "Sample translation 2."}}
}
response = excon.post(:body => "data=#{data.to_json}")
puts
puts "  Status:         #{response.status}"
puts

puts "Sleeping a second to avoid automatic 304"
sleep 1
puts

puts "(3) Incremental request... (GET with If-Modified-Since)"
headers = { 'If-Modified-Since' => @last_modified }
#debugger
response = excon.get(:headers => headers)
puts
puts "  Status:         #{response.status}"
puts "  Body size:      #{response.body.size}"
puts
