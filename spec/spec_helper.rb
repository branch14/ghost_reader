require 'rubygems'
require "webrick/httputils"
require "bundler"

Bundler.require(:default, :development)

# A Testhandler for Mongrel serving yaml-File and notice the data
class GhostHandler<Mongrel::HttpHandler

  def initialize
    @request_count=0
    @not_modified=false
    @modified_value='not_modified'
  end

  def modified=(value)
    @modified_value=value
  end

  def request_count
    @request_count
  end

  def last_params
    @last_params
  end

  def last_hits
    @last_hits
  end

  def last_miss
    @last_miss
  end

  def not_modified=(new_value)
    @not_modified=new_value
  end

  def process(request, response)
    @last_params=request.params
    if @last_params["REQUEST_METHOD"]=="POST"
      form_data= WEBrick::HTTPUtils::parse_query(request.body.readline)
      @last_hits=JSON::parse(form_data['hits'])
      @last_miss=JSON::parse(form_data['miss'])
    end

    if @not_modified
      response.start(304) do |head, out|
        out.write("")
      end
    else
      response.start(200) do |head, out|
        head["Content-Type"] = "text/plain"
        # Set Dummy-Last-Modified (only handled as String in ghost_reader)
        head["Last-Modified"] = Time.now.to_s
        # Put data for Client
        out.write({
                          'en'=>{
                                  'test'=>'hello'+(@request_count+=1).to_s,
                                  'modified'=>@modified_value,
                                  'scoped'=>{
                                          'test'=>'scoped_result'
                                  },
                                  'activerecord'=>{
                                          'errors'=>{
                                                  'messages'=>{
                                                          'odd'=>'Odd value'
                                                  }
                                          }
                                  },
                                  'thanks'=>'Thanks %{name}',
                                  'inbox'=>{
                                          'one'=> '1 message',
                                          'other'=>'%{count} messages'
                                  },
                                  'number'=>{
                                          'human'=>{
                                                  'format'=>{
                                                          'delimiter'=>''
                                                  }
                                          },
                                          'format'=>{
                                                  'separator'=>'.'
                                          }
                                  }
                          },
                          'de'=>{
                                  'thanks'=>'Danke %{name}'

                          },
                          'es'=>{'dummy'=>'nothing'}
                  }.to_yaml)
      end
    end
  end
end
#require 'active_support'
#require 'action_view/helpers/number_helper'
require 'action_view'

class Helper
  include ActionView::Helpers::NumberHelper
end
