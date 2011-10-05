require 'spec_helper'

module GhostReader
  describe Client do
    describe "#initial_request" do
      before(:each) do
        Excon.mock = true
        Excon.stub({:method => :get}, {:body => 'body',
                                       :status => 200,
                                       :headers => { "last-modified" => "Tue, 15 Sep 2011 14:25:38 GMT" }})
        @client = Client.new(test_config)
      end

      it "should return the status 200" do
        @client.initial_request[:status].should == 200
      end

      it "should return the data 'body'" do
        @client.initial_request[:data].should == 'body'
      end

      it "should return the timestamp" do
        @client.initial_request[:timestamp].should == "Tue, 15 Sep 2011 14:25:38 GMT"
      end
    end
  end
end

# Config data for the client initialization
def test_config
  {
    :retrieval_interval => 15,
    :report_interval => 10,
    :uri => 'http://ghost.panter.ch/api/:api_key/translations.json',
    :fallback => nil,
    :api_key => nil,
    :logfile => nil
  }
end
