require 'spec_helper'
require File.expand_path(File.join(%w(.. .. .. lib ghost_reader)), __FILE__)


Excon.mock = true

module Excon
  def self.kill_stubs!
    @stubs = nil
  end
end

describe GhostReader::Client do

  context 'on class level' do
    it 'should nicely initialize' do
      GhostReader::Client.new.should be_an_instance_of(GhostReader::Client)
    end
  end

  context 'a initialized client' do

    let(:client) { GhostReader::Client.new(:api_key => 'some+api_key') }

    before(:each) { Excon.kill_stubs! }

    it 'should nicely respond to initial_request' do
      body = {'some json' => 'here'}
      Excon.stub( { :method => :get },
                  { :body => body.to_json,
                    :status => 200,
                    :headers => { "last-modified" => httpdate } } )
      response = client.initial_request
      response[:status].should eq(200)
      response[:data].should eq(body)
    end

    it 'should try to reconnect configured number of times if there is timeout' do
      body = { 'some json' => 'here' }
      Excon.stub( { :method => :get },
                  { :body => body.to_json,
                    :status => 408,
                    :headers => { "last-modified" => httpdate } } )

      client.config.logger.should_receive(:error).exactly(3).times

      response = client.initial_request
    end

    it 'should nicely respond to reporting_request' do
      some_data = { 'some' => 'data' }
      Excon.stub( { :method => :post },
                  { :body => nil,
                    :status => 302 } )
      response = client.reporting_request(some_data)
      response[:status].should eq(302)
    end

    it 'should log error if reporting_request response is not a redirect' do
      some_data = { 'some' => 'data' }
      Excon.stub( { :method => :post },
                  { :body => nil,
                    :status => 200 })

      client.config.logger.should_receive(:error)

      response = client.reporting_request(some_data)
      response[:status].should eq(200)
    end

    it 'should nicely respond to incremental_request with 200' do
      body = {'some json' => 'here'}
      Excon.stub( { :method => :get },
                  { :body => body.to_json,
                    :status => 200,
                    :headers => { "last-modified" => httpdate } } )
      response = client.incremental_request
      response[:status].should eq(200)
      response[:data].should eq(body)
    end

    it 'should nicely respond to incremental_request with 304' do
      Excon.stub( { :method => :get },
                  { :body => nil,
                    :status => 304,
                    :headers => { "last-modified" => httpdate } } )
      response = client.incremental_request
      response[:status].should eq(304)
      response[:data].should be_nil
    end

  end

  def httpdate(time=Time.now)
    time.strftime('%a, %d %b %Y %H:%M:%S %Z')
  end

end

