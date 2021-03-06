# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "RestClient" do
  before do
    clear_all_traces
    @collect_backtraces = AppOpticsAPM::Config[:rest_client][:collect_backtraces]
  end

  after do
    AppOpticsAPM::Config[:rest_client][:collect_backtraces] = @collect_backtraces
  end

  it 'RestClient should be defined and ready' do
    defined?(::RestClient).wont_match nil
  end

  it 'RestClient should have appoptics_apm methods defined' do
    [ :execute_with_appoptics ].each do |m|
      ::RestClient::Request.method_defined?(m).must_equal true
    end
  end

  it "should report rest-client version in __Init" do
    init_kvs = ::AppOpticsAPM::Util.build_init_report

    init_kvs.key?('Ruby.rest-client.Version').must_equal true
    init_kvs['Ruby.rest-client.Version'].must_equal ::RestClient::VERSION
  end

  it "should trace a request to an instr'd app" do
    response = nil

    AppOpticsAPM::API.start_trace('rest_client_test') do
      response = RestClient.get 'http://127.0.0.1:8101/'
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'net-http'
    traces[2]['Label'].must_equal 'entry'

    traces[5]['Layer'].must_equal 'net-http'
    traces[5]['Label'].must_equal 'exit'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[5]['HTTPMethod'].must_equal 'GET'
    traces[5]['HTTPStatus'].must_equal "200"
    traces[5].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:nethttp][:collect_backtraces]

    traces[6]['Layer'].must_equal 'rest-client'
    traces[6]['Label'].must_equal 'exit'

    response.headers.key?(:x_trace).wont_equal nil
    xtrace = response.headers[:x_trace]

    AppOpticsAPM::XTrace.valid?(xtrace).must_equal true
  end

  it 'should trace a raw GET request' do
    AppOpticsAPM::API.start_trace('rest_client_test') do
      RestClient.get 'http://127.0.0.1:8101/?a=1'
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'net-http'
    traces[2]['Label'].must_equal 'entry'

    traces[5]['Layer'].must_equal 'net-http'
    traces[5]['Label'].must_equal 'exit'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?a=1'
    traces[5]['HTTPMethod'].must_equal 'GET'
    traces[5]['HTTPStatus'].must_equal "200"
    traces[5].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:nethttp][:collect_backtraces]

    traces[6]['Layer'].must_equal 'rest-client'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a raw POST request' do
    AppOpticsAPM::API.start_trace('rest_client_test') do
      RestClient.post 'http://127.0.0.1:8101/', :param1 => 'one', :nested => { :param2 => 'two' }
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'net-http'
    traces[2]['Label'].must_equal 'entry'

    traces[5]['Layer'].must_equal 'net-http'
    traces[5]['Label'].must_equal 'exit'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[5]['HTTPMethod'].must_equal 'POST'
    traces[5]['HTTPStatus'].must_equal "200"
    traces[5].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:nethttp][:collect_backtraces]

    traces[6]['Layer'].must_equal 'rest-client'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace a ActiveResource style GET request' do
    AppOpticsAPM::API.start_trace('rest_client_test') do
      resource = RestClient::Resource.new 'http://127.0.0.1:8101/?a=1'
      resource.get
    end

    traces = get_all_traces
    traces.count.must_equal 8

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'net-http'
    traces[2]['Label'].must_equal 'entry'

    traces[5]['Layer'].must_equal 'net-http'
    traces[5]['Label'].must_equal 'exit'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/?a=1'
    traces[5]['HTTPMethod'].must_equal 'GET'
    traces[5]['HTTPStatus'].must_equal "200"
    traces[5].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:nethttp][:collect_backtraces]

    traces[6]['Layer'].must_equal 'rest-client'
    traces[6]['Label'].must_equal 'exit'
  end

  it 'should trace requests with redirects' do
    AppOpticsAPM::API.start_trace('rest_client_test') do
      resource = RestClient::Resource.new 'http://127.0.0.1:8101/redirectme?redirect_test'
      response = resource.get
    end

    traces = get_all_traces
    traces.count.must_equal 14

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'net-http'
    traces[2]['Label'].must_equal 'entry'

    traces[5]['Layer'].must_equal 'net-http'
    traces[5]['Label'].must_equal 'exit'
    traces[5]['IsService'].must_equal 1
    traces[5]['RemoteURL'].must_equal 'http://127.0.0.1:8101/redirectme?redirect_test'
    traces[5]['HTTPMethod'].must_equal 'GET'
    traces[5]['HTTPStatus'].must_equal "301"
    traces[5].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:nethttp][:collect_backtraces]

    traces[6]['Layer'].must_equal 'rest-client'
    traces[6]['Label'].must_equal 'entry'

    traces[7]['Layer'].must_equal 'net-http'
    traces[7]['Label'].must_equal 'entry'

    traces[10]['Layer'].must_equal 'net-http'
    traces[10]['Label'].must_equal 'exit'
    traces[10]['IsService'].must_equal 1
    traces[10]['RemoteURL'].must_equal 'http://127.0.0.1:8101/'
    traces[10]['HTTPMethod'].must_equal 'GET'
    traces[10]['HTTPStatus'].must_equal "200"
    traces[10].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:nethttp][:collect_backtraces]

    traces[11]['Layer'].must_equal 'rest-client'
    traces[11]['Label'].must_equal 'exit'

    traces[12]['Layer'].must_equal 'rest-client'
    traces[12]['Label'].must_equal 'exit'
  end

  it 'should trace and capture raised exceptions' do
    AppOpticsAPM::API.start_trace('rest_client_test') do
      begin
        RestClient.get 'http://s6KTgaz7636z/resource'
      rescue
        # We want an exception to be raised.  Just don't raise
        # it beyond this point.
      end
    end

    traces = get_all_traces
    traces.count.must_equal 5

    valid_edges?(traces).must_equal true
    validate_outer_layers(traces, 'rest_client_test')

    traces[1]['Layer'].must_equal 'rest-client'
    traces[1]['Label'].must_equal 'entry'

    traces[2]['Layer'].must_equal 'rest-client'
    traces[2]['Spec'].must_equal 'error'
    traces[2]['Label'].must_equal 'error'
    traces[2]['ErrorClass'].must_equal 'SocketError'
    traces[2].key?('ErrorMsg').must_equal true
    traces[2].key?('Backtrace').must_equal !!AppOpticsAPM::Config[:nethttp][:collect_backtraces]

    traces.select { |trace| trace['Label'] == 'error' }.count.must_equal 1

    traces[3]['Layer'].must_equal 'rest-client'
    traces[3]['Label'].must_equal 'exit'
  end

  it 'should obey :collect_backtraces setting when true' do
    AppOpticsAPM::Config[:rest_client][:collect_backtraces] = true

    AppOpticsAPM::API.start_trace('rest_client_test') do
      RestClient.get('http://127.0.0.1:8101/', {:a => 1})
    end

    traces = get_all_traces
    layer_has_key(traces, 'rest-client', 'Backtrace')
  end

  it 'should obey :collect_backtraces setting when false' do
    AppOpticsAPM::Config[:rest_client][:collect_backtraces] = false

    AppOpticsAPM::API.start_trace('rest_client_test') do
      RestClient.get('http://127.0.0.1:8101/', {:a => 1})
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'rest-client', 'Backtrace')
  end
end
