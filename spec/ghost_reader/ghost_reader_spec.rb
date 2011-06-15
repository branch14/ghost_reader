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

  it('can format a size') do
    Helper.new.number_to_human_size(12389506).should == '11.8 MB'
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
                                  "inbox.one"=>1,
                                  "inbox.other"=>1,
                                  "number.human.format.delimiter"=>1,
                                  "number.format.separator"=>3,
                                  "activerecord.errors.messages.odd"=>1,
                                  "test"=>1}
  end

  it('cache-miss with fallback-values') do
    @handler.last_miss.should =={
            "notfound"=>{
                    "default"=>{"de"=>"Nicht gefunden", "en"=>"Not found"},
                    "count"=>{"en"=>1}
            },
            "scoped.fallback"=>{
                    "default"=>{"en"=>"fallback_value"},
                    "count"=>{"en"=>2}
            },
            "activerecord.errors.messages.even"=>{
                    "default"=>{"en"=>"Even value"},
                    "count"=>{"en"=>1}
            },
            "number.format.delimiter"=>{
                    "default"=>{"en"=>","},
                    "count"=>{"en"=>3}
            },
            "number.format.precision"=>{
                    "default"=>{"en"=>3},
                    "count"=>{"en"=>3}
            },
            "number.format.strip_insignificant_zeros"=> {
                    "default"=>{"en"=>false},
                    "count"=>{"en"=>3}
            },

            "number.human.storage_units.format"=>{
                    "default"=>{"en"=>"%n %u"},
                    "count"=>{"en"=>1}
            },
            "number.format.significant"=>{
                    "default"=>{"en"=>false},
                    "count"=>{"en"=>3}
            },
            "number.human.format.strip_insignificant_zeros"=>{
                    "default"=>{"en"=>true},
                    "count"=>{"en"=>1}
            },
            "number.human.format.precision"=>{
                    "default"=>{"en"=>3},
                    "count"=>{"en"=>1}
            },
            "number.precision.format.delimiter"=>{
                    "default"=>{"en"=>""},
                    "count"=>{"en"=>1}
            },
            "number.format.strip_insignificant_zeros"=>{
                    "default"=>{"en"=>false},
                    "count"=>{"en"=>3}
            },
            "number.human.format.significant"=>{
                    "default"=>{"en"=>true},
                    "count"=>{"en"=>1}
            },
            "number.human.format.precision"=>{
                    "default"=>{"en"=>3},
                    "count"=>{"en"=>1}
            },
            "number.human.storage_units.units.mb"=>{
                    "default"=>{"en"=>"MB"},
                    "count"=>{"en"=>1}
            }
    }
  end

  it('if-modified-since is set') do
    @handler.last_params["HTTP_IF_MODIFIED_SINCE"].should_not be_nil
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
                            "en"=>"%a, %d %b %Y %H:%M:%S %z"
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
            },
            "number.human.format.delimiter"=>{
                    "default"=>{"en"=>""},
                    "count"=>{}
            },
            "errors.messages.blank"=>{
                    "default"=>{"en"=>"can't be blank"},
                    "count"=>{}
            },
            "datetime.prompts.second"=>{
                    "default"=>{"en"=>"Seconds"},
                    "count"=>{}
            },
            "number.format.separator"=>{
                    "default"=>{"en"=>"."},
                    "count"=>{}
            },
            "errors.messages.not_a_number"=>{
                    "default"=>{"en"=>"is not a number"},
                    "count"=>{}
            },
            "support.array.last_word_connector"=>{
                    "default"=>{"en"=>", and "},
                    "count"=>{}
            },
            "errors.messages.empty"=>{
                    "default"=>{"en"=>"can't be empty"},
                    "count"=>{}
            },
            "number.human.storage_units.format"=>{
                    "default"=>{"en"=>"%n %u"},
                    "count"=>{}
            },
            "support.array.words_connector"=>{
                    "default"=>{"en"=>", "},
                    "count"=>{}
            },
            "number.format.delimiter"=>{
                    "default"=>{"en"=>","},
                    "count"=>{}
            },
            "datetime.distance_in_words.x_seconds.other"=>{
                    "default"=>{"en"=>"%{count} seconds"},
                    "count"=>{}
            },
            "datetime.prompts.minute"=>{
                    "default"=>{"en"=>"Minute"},
                    "count"=>{}
            },
            "datetime.distance_in_words.less_than_x_seconds.other"=>{
                    "default"=>{"en"=>"less than %{count} seconds"},
                    "count"=>{}
            },
            "support.array.two_words_connector"=>{
                    "default"=>{"en"=>" and "},
                    "count"=>{}
            },
            "datetime.distance_in_words.half_a_minute"=>{
                    "default"=>{"en"=>"half a minute"},
                    "count"=>{}
            },
            "errors.messages.equal_to"=>{
                    "default"=>{"en"=>"must be equal to %{count}"},
                    "count"=>{}
            },
            "errors.messages.not_an_integer"=>{
                    "default"=>{"en"=>"must be an integer"},
                    "count"=>{}
            },
            "datetime.distance_in_words.about_x_years.one"=>{
                    "default"=>{"en"=>"about 1 year"},
                    "count"=>{}
            },
            "datetime.distance_in_words.x_minutes.other"=>{
                    "default"=>{"en"=>"%{count} minutes"},
                    "count"=>{}
            },
            "number.currency.format.delimiter"=>{
                    "default"=>{"en"=>","},
                    "count"=>{}},
            "number.human.storage_units.units.mb"=>{
                    "default"=>{"en"=>"MB"},
                    "count"=>{}},
            "date.formats.default"=>{
                    "default"=>{"en"=>"%Y-%m-%d"},
                    "count"=>{}},
            "datetime.distance_in_words.less_than_x_minutes.other"=>{
                    "default"=>{"en"=>"less than %{count} minutes"},
                    "count"=>{}},
            "helpers.select.prompt"=>{
                    "default"=>{"en"=>"Please select"},
                    "count"=>{}},
            "datetime.prompts.month"=>{
                    "default"=>{"en"=>"Month"},
                    "count"=>{}},
            "datetime.prompts.year"=>{
                    "default"=>{"en"=>"Year"},
                    "count"=>{}},
            "number.human.storage_units.units.kb"=>{
                    "default"=>{"en"=>"KB"},
                    "count"=>{}},
            "number.human.decimal_units.units.unit"=>{
                    "default"=>{"en"=>""},
                    "count"=>{}},
            "datetime.distance_in_words.x_days.other"=>{
                    "default"=>{"en"=>"%{count} days"},
                    "count"=>{}},
            "datetime.distance_in_words.about_x_hours.one"=>{
                    "default"=>{"en"=>"about 1 hour"},
                    "count"=>{}},
            "errors.messages.too_long"=>{
                    "default"=>{
                            "en"=>"is too long (maximum is %{count} characters)"
                    },
                    "count"=>{}},
            "number.currency.format.unit"=>{"default"=>{"en"=>"$"},
                                            "count"=>{}},
            "errors.messages.invalid"=>{
                    "default"=>{"en"=>"is invalid"},
                    "count"=>{}},
            "datetime.distance_in_words.almost_x_years.one"=>{
                    "default"=>{"en"=>"almost 1 year"},
                    "count"=>{}},
            "datetime.distance_in_words.about_x_months.other"=>{
                    "default"=>{"en"=>"about %{count} months"},
                    "count"=>{}},
            "errors.messages.inclusion"=>{
                    "default"=>{"en"=>"is not included in the list"},
                    "count"=>{}},
            "errors.messages.odd"=>{
                    "default"=>{"en"=>"must be odd"},
                    "count"=>{}},
            "datetime.distance_in_words.about_x_years.other"=>{
                    "default"=>{"en"=>"about %{count} years"},
                    "count"=>{}},
            "time.am"=>{
                    "default"=>{"en"=>"am"},
                    "count"=>{}},
            "datetime.distance_in_words.almost_x_years.other"=>{
                    "default"=>{"en"=>"almost %{count} years"},
                    "count"=>{}},
            "helpers.submit.submit"=>{
                    "default"=>{"en"=>"Save %{model}"},
                    "count"=>{}},
            "number.human.storage_units.units.byte.other"=>{
                    "default"=>{"en"=>"Bytes"},
                    "count"=>{}},
            "errors.messages.even"=>{
                    "default"=>{"en"=>"must be even"},
                    "count"=>{}},
            "number.human.storage_units.units.gb"=>{
                    "default"=>{"en"=>"GB"},
                    "count"=>{}},
            "datetime.distance_in_words.x_minutes.one"=>{
                    "default"=>{"en"=>"1 minute"},
                    "count"=>{}},
            "datetime.distance_in_words.about_x_hours.other"=>{
                    "default"=>{"en"=>"about %{count} hours"},
                    "count"=>{}},
            "number.human.decimal_units.units.thousand"=>{
                    "default"=>{"en"=>"Thousand"},
                    "count"=>{}},
            "errors.messages.less_than_or_equal_to"=>{
                    "default"=>{"en"=>"must be less than or equal to %{count}"},
                    "count"=>{}},
            "time.pm"=>{
                    "default"=>{"en"=>"pm"},
                    "count"=>{}},
            "datetime.distance_in_words.x_days.one"=>{
                    "default"=>{"en"=>"1 day"},
                    "count"=>{}},
            "errors.messages.less_than"=>{
                    "default"=>{"en"=>"must be less than %{count}"},
                    "count"=>{}},
            "number.percentage.format.delimiter"=>{
                    "default"=>{"en"=>""},
                    "count"=>{}},
            "number.human.decimal_units.units.trillion"=>{
                    "default"=>{"en"=>"Trillion"},
                    "count"=>{}},
            "number.precision.format.delimiter"=>{
                    "default"=>{"en"=>""},
                    "count"=>{}},
            "time.formats.short"=>{
                    "default"=>{"en"=>"%d %b %H:%M"},
                    "count"=>{}},
            "number.currency.format.format"=>{
                    "default"=>{"en"=>"%u%n"},
                    "count"=>{}},
            "number.human.storage_units.units.tb"=>{
                    "default"=>{"en"=>"TB"},
                    "count"=>{}},
            "errors.messages.confirmation"=>{
                    "default"=>{"en"=>"doesn't match confirmation"},
                    "count"=>{}},
            "datetime.distance_in_words.over_x_years.other"=>{
                    "default"=>{"en"=>"over %{count} years"},
                    "count"=>{}},
            "helpers.submit.update"=>{
                    "default"=>{"en"=>"Update %{model}"},
                    "count"=>{}},
            "number.human.decimal_units.units.quadrillion"=>{
                    "default"=>{"en"=>"Quadrillion"},
                    "count"=>{}},
            "datetime.distance_in_words.x_months.one"=>{
                    "default"=>{"en"=>"1 month"},
                    "count"=>{}},
            "datetime.distance_in_words.less_than_x_minutes.one"=>{
                    "default"=>{"en"=>"less than a minute"},
                    "count"=>{}},
            "errors.messages.greater_than"=>{
                    "default"=>{"en"=>"must be greater than %{count}"},
                    "count"=>{}},
            "number.human.decimal_units.format"=>{
                    "default"=>{"en"=>"%n %u"},
                    "count"=>{}},
            "datetime.prompts.day"=>{"default"=>{"en"=>"Day"}, "count"=>{}},
            "date.formats.short"=>{"default"=>{"en"=>"%b %d"}, "count"=>{}},
            "datetime.prompts.hour"=>{"default"=>{"en"=>"Hour"}, "count"=>{}},
            "number.human.decimal_units.units.billion"=>{"default"=>{"en"=>"Billion"}, "count"=>{}},
            "number.currency.format.separator"=>{"default"=>{"en"=>"."}, "count"=>{}},
            "time.formats.long"=>{"default"=>{"en"=>"%B %d, %Y %H:%M"}, "count"=>{}},
            "errors.format"=>{"default"=>{"en"=>"%{attribute} %{message}"}, "count"=>{}},
            "errors.messages.wrong_length"=>{"default"=>{"en"=>"is the wrong length (should be %{count} characters)"}, "count"=>{}},
            "number.human.storage_units.units.byte.one"=>{"default"=>{"en"=>"Byte"}, "count"=>{}},
            "errors.messages.exclusion"=>{"default"=>{"en"=>"is reserved"}, "count"=>{}},
            "errors.messages.greater_than_or_equal_to"=>{"default"=>{"en"=>"must be greater than or equal to %{count}"}, "count"=>{}},
            "errors.messages.accepted"=>{"default"=>{"en"=>"must be accepted"}, "count"=>{}},
            "errors.messages.too_short"=>{"default"=>{"en"=>"is too short (minimum is %{count} characters)"}, "count"=>{}},
            "helpers.submit.create"=>{"default"=>{"en"=>"Create %{model}"}, "count"=>{}},
            "datetime.distance_in_words.x_months.other"=>{"default"=>{"en"=>"%{count} months"}, "count"=>{}},
            "datetime.distance_in_words.x_seconds.one"=>{"default"=>{"en"=>"1 second"}, "count"=>{}},
            "datetime.distance_in_words.about_x_months.one"=>{"default"=>{"en"=>"about 1 month"}, "count"=>{}},
            "date.formats.long"=>{"default"=>{"en"=>"%B %d, %Y"}, "count"=>{}},
            "number.human.decimal_units.units.million"=>{"default"=>{"en"=>"Million"}, "count"=>{}},
            "datetime.distance_in_words.over_x_years.one"=>{"default"=>{"en"=>"over 1 year"}, "count"=>{}},
            "datetime.distance_in_words.less_than_x_seconds.one"=>{"default"=>{"en"=>"less than 1 second"}, "count"=>{}}
    }
  }
  it('can read availbale locales from default-Backend and from ghost-server') {
    available_locales = I18n.backend.available_locales
    available_locales.include?(:de).should == true
    available_locales.include?(:pt).should == true
    available_locales.include?(:es).should == true
  }
end
