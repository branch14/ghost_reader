require 'spec_helper'

describe GhostReader::NewBackend do

  context 'on class level' do
    it 'should nicely initialize' do
      backend = GhostReader::NewBackend.new
    end
  end

  context 'Backend set up with fallback' do
    
    before(:each) do
      @translation = 'This is a test.'
      @fallback = mock "FallbackBackend"
      @fallback.stub!(:translate).and_return(@translation)
      @backend = GhostReader::NewBackend.new(:fallback => @fallback)
    end
    
    it 'should use the given fallback' do
      @backend.config.fallback.should be(@fallback)
      @fallback.should_receive(:translate)
      @backend.translate(:en, 'this.is.a.test').should eq(@translation)
    end

    it 'should track missings' do
      @backend.missings = {} # fake init
      @backend.translate(:en, 'this.is.a.test')
      @backend.missings.keys.should eq(['this.is.a.test'])
    end

    it 'should use memoization' do
      @fallback.should_receive(:translate).exactly(1)
      2.times { @backend.translate(:en, 'this.is.a.test').should eq(@translation) }
    end

  end
end
