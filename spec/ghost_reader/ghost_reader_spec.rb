require 'spec_helper'

describe "Ghost Reader" do
  before(:all) do
#    I18n.locale=:en
    fallback = I18n::Backend::Simple.new
    fallback.store_translations(:en, {:notfound=>'Not found',
                                      :scoped=>{:fallback=>'fallback_value'},
                                      :time=>{
                                              :formats=>{
                                                      :default=>'%Y-%d-%m'}
                                      },
                                      'activerecord'=>{
                                              'errors'=>{
                                                      'messages'=>{
                                                              'even'=>'Even value'
                                                      }
                                              }
                                      }

    })
    fallback.store_translations(:de, {:notfound=>'Nicht gefunden'})
    fallback.store_translations(:pt, {:dummy=>''})
    # Initializes a Handler
    @handler=GhostHandler.new
    # Start a Mongrel-Server for Testing Ghost Reader
    @server = Mongrel::HttpServer.new('0.0.0.0', 35623)
    @server.register('/', @handler)
    @server.run
    # Short Wait-Time for Testing
    I18n.backend=GhostReader::Backend.new("http://localhost:35623/",
                                          :default_backend=>fallback,
                                          :wait_time=>1)
    # Wait for finishing first call in background
    sleep 3
  end
  after(:all) do
    # Shutdown the Mongrel-Server
    @server.stop
  end
  it('first call should not set if-modified-since') do
    @handler.last_params["HTTP_IF_MODIFIED_SINCE"].should == nil
  end

  it('can translate the key "test"') do
    I18n.t('test').should == "hello1"
  end
  it('can handle scoped request') do
    I18n.t('test', :scope=>'scoped').should == "scoped_result"
  end
  it('can handle scoped fallback') do
    I18n.t('fallback', :scope=>'scoped').should == "fallback_value"
  end

  it('can Handle scoped request in array-notation') do
    I18n.t('fallback', :scope=>['scoped']).should == "fallback_value"
  end

  it('can handle bulk lookup') do
    I18n.t([:odd, :even], :scope => 'activerecord.errors.messages').should ==
            ['Odd value', 'Even value']
  end

  it('can handle interpolation') do
    I18n.t(:thanks, :name=>'Jeremy').should == "Thanks Jeremy"
  end

  it('can handle pluralization') do
    I18n.t(:inbox, :count=>2).should == "2 messages"
  end

  it('can handle a explicit locale') do
    I18n.t(:thanks, :name=>'Jeremy', :locale=>:de).should == "Danke Jeremy"
  end


  it('can localize a time') do
    Time.now.should_not == nil
  end

  it('Cache miss not the fallback') {
    I18n.t('notfound').should == "Not found"
  }

  it('can translate the key "test" with a update-post') do
    sleep 2
    I18n.t('test').should == "hello2"
  end

  it('hit recorded') do
    sleep 2
    @handler.last_hits.should == {"thanks"=>2,
                                  "scoped.test"=>1,
                                  "inbox"=>1,
                                  "activerecord.errors.messages.odd"=>1,
                                  "test"=>1}
  end

  it('cache-miss with fallback-values') do
    @handler.last_miss.should == {
            "notfound"=>{
                    "default"=>{
                            "de"=>"Nicht gefunden",
                            "en"=>"Not found"},
                    "count"=>{
                            "en"=>1
                    }
            },
            'scoped.fallback'=>{
                    'default'=>{
                            'en'=>'fallback_value'
                    },
                    'count'=>{
                            'en'=>2
                    }
            },
            "activerecord.errors.messages.even"=>{
                    "default"=>{
                            "en"=>"Even value"
                    },
                    "count"=>{
                            "en"=>1
                    }
            }
    }
  end

  it('if-modified-since is set') do
    @handler.last_params["HTTP_IF_MODIFIED_SINCE"].should_not == nil
  end
  it('can translate the key "test" with a update-post') do
    @handler.not_modified=true
    @handler.modified='modified'
    sleep 2
    I18n.t('modified').should == "not_modified"
  end
  it('can push all data from Backend to server') {
    I18n.backend.push_all_backend_data
    @handler.last_miss.should == {
            "notfound"=>{
                    "default"=>{
                            "de"=>"Nicht gefunden",
                            "en"=>"Not found"},
                    'count'=>{}
            },
            'scoped.fallback'=>{
                    'default'=>{
                            'en'=>'fallback_value'
                    },
                    'count'=>{}
            },
            "time.formats.default"=>{
                    "default"=>{
                            "en"=>"%Y-%d-%m"
                    },
                    "count"=>{}
            },
            "activerecord.errors.messages.even"=> {
                    "default"=>{
                            "en"=>"Even value"
                    },
                    "count"=>{}
            },
            'dummy'=>{
                    'default'=>{
                            'pt'=>''
                    },
                    'count'=>{}
            }
    }
  }
  it('can read availbale locales from default-Backend and from ghost-server') {
    available_locales = I18n.backend.available_locales
    available_locales.include?(:de).should == true
    available_locales.include?(:pt).should == true
    available_locales.include?(:es).should == true
  }
end