require 'spec_helper'

module GhostReader
  describe Client do

    before(:each) do
      Excon.mock = true
    end

    describe "#initialization" do
      it "should raise exception for missing api key" do
        bad_config = { :api_key => nil }
        Client.new(bad_config).should raise_error
      end
    end

    describe "#initial_request" do
      before(:each) do
        #TODO: replace this with real life example
        Excon.stub({:method => :get}, { :body => { "test" => "hello"  }.to_json,
                                        :status => 200,
                                        :headers => { "last-modified" => "Tue, 15 Sep 2011 14:25:38 GMT" }})
        @client = Client.new(test_config)
      end

      context "successful" do
        it "should return the status 200" do
          @client.initial_request[:status].should == 200
        end

        it "should return the JSON data" do
          @client.initial_request[:data].should == { 'test' => 'hello' }
        end

        it "should return the timestamp" do
          @client.initial_request[:timestamp].should == "Tue, 15 Sep 2011 14:25:38 GMT"
        end
      end
    end

    describe "#reporting_request" do

    end

    describe "#incremental_request" do
      before(:each) do
        #TODO: replace this with real life example
        Excon.stub({:method => :get}, { :body => { "test" => "hello"  }.to_json,
                                        :status => 200,
                                        :headers => { "last-modified" => "Tue, 15 Sep 2011 14:25:38 GMT" }})
        @client = Client.new(test_config)
      end
    end

  end
end

# Config data for the client initialization
def test_config
  {
    :retrieval_interval => 15,
    :report_interval => 10,
    :fallback => nil,
    :api_key => '12345',
    :logfile => nil
  }
end

