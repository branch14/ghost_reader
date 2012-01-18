require 'spec_helper'

describe GhostReader::Backend do

  let(:dev_null) { File.new('/dev/null', 'w') }

  let(:client) do
    mock("Client").tap do |client|
      response = {'en' => {'this' => {'is' => {'a' => {'test' => 'This is a test.'}}}}}
      client.stub!(:initial_request).and_return(:data => response)
      client.stub!(:incremental_request).and_return(:data => response)
      client.stub!(:reporting_request)
    end
  end

  context 'on class level' do
    it 'should nicely initialize' do
      GhostReader::Backend.new( :logfile => dev_null ).should be_instance_of(GhostReader::Backend)
    end
  end

  context 'Backend set up with fallback' do

    let(:translation) { 'This is a test.' }

    let(:fallback) do
      mock("FallbackBackend").tap do |fallback|
        fallback.stub!(:translate).and_return(translation)
      end
    end

    let(:backend) do
      GhostReader::Backend.new( :logfile => dev_null,
                                :log_level => Logger::DEBUG,
                                :fallback => fallback )
    end

    it 'should use the given fallback' do
      backend.config.fallback.should be(fallback)
      fallback.should_receive(:translate)
      backend.translate(:en, 'this.is.a.test').should eq(translation)
    end

    it 'should track missings' do
      backend.missings = {} # fake init
      backend.translate(:en, 'this.is.a.test')
      backend.missings.keys.should eq(['this.is.a.test'])
    end

    it 'should use memoization' do
      fallback.should_receive(:translate).exactly(1)
      2.times { backend.translate(:en, 'this.is.a.test').should eq(translation) }
    end

    it 'should symbolize keys' do
      test_data = { "one" => "1", "two" => "2"}
      result = backend.send(:symbolize_keys, test_data)
      result.has_key?(:one).should be_true
    end

    it 'should nicely respond to available_locales' do
      backend.should respond_to(:available_locales)

      expected = [:en, :de]
      fallback.stub!(:available_locales).and_return(expected)
      backend.available_locales.should eq(expected)

      # FIXME
      # backend.send(:memoize_merge!, :it => {'dummay' => 'Dummy'})
      # backend.translate(:it, 'this.is.a.test')
      # backend.available_locales.should eq([:it, :en, :de])
    end

    context 'nicely merge data into memoized_hash' do

      it 'should work with valid data' do
        data = {'en' => {'this' => {'is' => {'a' => {'test' => 'This is a test.'}}}}}
        backend.send(:memoize_merge!, data)
        backend.send(:memoized_lookup).should have_key(:en)
        # flattend and symbolized
        backend.send(:memoized_lookup)[:en].should have_key(:'this.is.a.test')
      end

      it 'should handle weird data gracefully' do
        expect do
          data = {'en' => {'value_is_an_hash' => {'1st' => 'bla', '2nd' => 'blub'}}}
          backend.send(:memoize_merge!, data)
          data = {'en' => {'empty_value' => ''}}
          backend.send(:memoize_merge!, data)
          data = {'en' => {'' => 'Empty key.'}} 
          backend.send(:memoize_merge!, data) # 'interning empty string'
          data = {'en' => {'value_is_an_array' => %w(what the fuck)}}
          backend.send(:memoize_merge!, data)
        end.to_not raise_error
      end
      
      # key should not be empty but if it is...
      it 'should not raise error when key is empty' do
        data = {'en' => {'' => 'Empty key.'}} 
        backend.send(:memoize_merge!, data) # 'interning empty string'
        backend.send(:memoized_lookup).should be_empty
      end

    end

  end

  context 'GhostReader set up without fallback' do
    let(:backend) { GhostReader::Backend.new(:logfile => dev_null) }
    
    it 'should raise an error' do
      expect { backend.translate(:de, :asdf) }.to raise_error('no fallback given')
    end
  end
  
  context 'GhostReader set up with raising fallback' do
    let(:fallback) do
      mock("FallbackBackend").tap do |fallback|
        fallback.stub!(:translate) do
          raise 'missing translation'
        end
      end
    end

    let(:backend) do
      GhostReader::Backend.new( :logfile => dev_null,
                                :log_level => Logger::DEBUG,
                                :fallback => fallback,
                                :client => client )
    end

    it 'should behave nicely' do
      expect { backend.translate(:de, :asdf) }.to raise_error('missing translation') 
    end

    it 'should track lookups which raise exceptions' do
      # backend.retriever.should be_alive
      backend.missings = {} # fake initialize
      backend.missings.should be_empty
      expect { backend.translate(:de, :asdf) }.to raise_error('missing translation')
      backend.missings.should_not be_empty
    end
  end

end
