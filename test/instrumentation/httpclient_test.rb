# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'appoptics_apm/inst/rack'
  require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

  class HTTPClientTest < Minitest::Test
    include Rack::Test::Methods

    def app
      SinatraSimple
    end

    def setup
      clear_all_traces
      AppOpticsAPM::Config[:tracing_mode] = :always
    end

    def teardown
      clear_all_traces
    end

    def test_reports_version_init
      init_kvs = ::AppOpticsAPM::Util.build_init_report
      assert init_kvs.key?('Ruby.httpclient.Version')
      assert_equal ::HTTPClient::VERSION, init_kvs['Ruby.httpclient.Version']
    end

    def test_get_request
      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })

        # Validate returned xtrace
        assert response.headers.key?("X-Trace")
        assert AppOpticsAPM::XTrace.valid?(response.headers["X-Trace"])
      end

      traces = get_all_traces
      assert_equal 6, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 'rsc', traces[1]['Spec']
      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/?keyword=ruby&lang=en'
      assert_equal traces[1]['HTTPMethod'], 'GET'

      assert_equal traces[4]['Layer'], 'httpclient'
      assert_equal traces[4]['Label'], 'exit'
      assert_equal traces[4]['HTTPStatus'], 200
      assert traces[4].key?('Backtrace')
    end

    def test_get_request_to_uninstr_app
      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8110/', :query => { :keyword => 'ruby', :lang => 'en' })
        refute response.headers.key?("X-Trace")
      end

      traces = get_all_traces
      assert_equal 4, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 'rsc', traces[1]['Spec']
      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8110/?keyword=ruby&lang=en'
      assert_equal traces[1]['HTTPMethod'], 'GET'

      assert_equal traces[2]['Layer'], 'httpclient'
      assert_equal traces[2]['Label'], 'exit'
      assert_equal traces[2]['HTTPStatus'], 200
      assert traces[2].key?('Backtrace')
    end

    def test_get_with_header_hash
      response = nil

      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', nil, { "SOAPAction" => "HelloWorld" })
      end

      traces = get_all_traces
      xtrace = response.headers['X-Trace']
      assert xtrace
      assert AppOpticsAPM::XTrace.valid?(xtrace)

      assert_equal 6, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 'rsc', traces[1]['Spec']
      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
      assert_equal traces[1]['HTTPMethod'], 'GET'

      assert_equal traces[4]['Layer'], 'httpclient'
      assert_equal traces[4]['Label'], 'exit'
      assert_equal traces[4]['HTTPStatus'], 200
      assert traces[4].key?('Backtrace')
    end

    def test_get_with_header_array
      response = nil

      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', nil, [["Accept", "text/plain"], ["Accept", "text/html"]])
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert AppOpticsAPM::XTrace.valid?(xtrace)

      assert_equal 6, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 'rsc', traces[1]['Spec']
      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
      assert_equal traces[1]['HTTPMethod'], 'GET'

      assert_equal traces[4]['Layer'], 'httpclient'
      assert_equal traces[4]['Label'], 'exit'
      assert_equal traces[4]['HTTPStatus'], 200
      assert traces[4].key?('Backtrace')
    end

    def test_post_request
      response = nil

      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.post('http://127.0.0.1:8101/')
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert AppOpticsAPM::XTrace.valid?(xtrace)

      assert_equal 6, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 'rsc', traces[1]['Spec']
      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
      assert_equal traces[1]['HTTPMethod'], 'POST'

      assert_equal traces[4]['Layer'], 'httpclient'
      assert_equal traces[4]['Label'], 'exit'
      assert_equal traces[4]['HTTPStatus'], 200
      assert traces[4].key?('Backtrace')
    end

    def test_async_get
      conn = nil

      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        conn = clnt.get_async('http://127.0.0.1:8101/?blah=1')
      end

      # Allow async request to finish
      Thread.pass until conn.finished?

      traces = get_all_traces

      assert_equal 6, traces.count
      assert valid_edges?(traces, false), "Invalid edge in traces"

      # In the case of async the layers are not always ordered the same
      # validate_outer_layers is not applicable, so we make sure we get the pair for 'httpclient_tests'
      assert_equal 2, traces.select { |trace| trace['Layer'] == 'httpclient_tests' }.size

      # because of possible different ordering of traces we can't rely on an index and need to use find
      async_entry = traces.find { |trace| trace['Layer'] == 'httpclient' && trace['Label'] == 'entry' }
      assert_equal 'rsc', async_entry['Spec']
      assert_equal 1, async_entry['Async']
      assert_equal 1, async_entry['IsService']
      assert_equal 'http://127.0.0.1:8101/?blah=1', async_entry['RemoteURL']
      assert_equal 'GET', async_entry['HTTPMethod']

      assert_equal 'httpclient', traces[5]['Layer']
      assert_equal 'exit', traces[5]['Label']
      assert_equal 200, traces[5]['HTTPStatus']
      assert traces[5].key?('Backtrace')
    end

    def test_cross_app_tracing
      response = nil

      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
      end

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert AppOpticsAPM::XTrace.valid?(xtrace)

      traces = get_all_traces

      assert_equal 6, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 'rsc', traces[1]['Spec']
      assert_equal 1, traces[1]['IsService']
      assert_equal 'http://127.0.0.1:8101/?keyword=ruby&lang=en', traces[1]['RemoteURL']
      assert_equal 'GET', traces[1]['HTTPMethod']

      assert_equal 'rack', traces[2]['Layer']
      assert_equal 'entry', traces[2]['Label']
      assert_equal 'rack', traces[3]['Layer']
      assert_equal 'exit', traces[3]['Label']

      assert_equal 'httpclient', traces[4]['Layer']
      assert_equal 'exit', traces[4]['Label']
      assert_equal 200, traces[4]['HTTPStatus']
      assert traces[4].key?('Backtrace')
    end

    def test_requests_with_errors
      result = nil
      begin
        AppOpticsAPM::API.start_trace('httpclient_tests') do
          clnt = HTTPClient.new
          clnt.get('http://asfjalkfjlajfljkaljf/')
        end
      rescue
      end

      traces = get_all_traces
      assert_equal 5, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 'rsc', traces[1]['Spec']
      assert_equal 1, traces[1]['IsService']
      assert_equal 'http://asfjalkfjlajfljkaljf/', traces[1]['RemoteURL']
      assert_equal 'GET', traces[1]['HTTPMethod']

      assert_equal 'httpclient', traces[2]['Layer']
      assert_equal 'error', traces[2]['Spec']
      assert_equal 'error', traces[2]['Label']
      assert_equal 1, traces.select { |trace| trace['Label'] == 'error' }.count

      assert_equal "SocketError", traces[2]['ErrorClass']
      assert traces[2].key?('ErrorMsg')
      assert traces[2].key?('Backtrace')
      assert_equal 1, traces.select { |trace| trace['Label'] == 'error' }.count

      assert_equal 'httpclient', traces[3]['Layer']
      assert_equal 'exit', traces[3]['Label']
      assert traces[3].key?('Backtrace')
    end

    def test_log_args_when_true
      @log_args = AppOpticsAPM::Config[:httpclient][:log_args]
      AppOpticsAPM::Config[:httpclient][:log_args] = true

      response = nil

      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert AppOpticsAPM::XTrace.valid?(xtrace)

      assert_equal 6, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"

      assert_equal 'http://127.0.0.1:8101/?keyword=ruby&lang=en', traces[1]['RemoteURL']

      AppOpticsAPM::Config[:httpclient][:log_args] = @log_args
    end

    def test_log_args_when_false
      @log_args = AppOpticsAPM::Config[:httpclient][:log_args]
      AppOpticsAPM::Config[:httpclient][:log_args] = false

      response = nil

      AppOpticsAPM::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert AppOpticsAPM::XTrace.valid?(xtrace)

      assert_equal 6, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"

      assert_equal 'http://127.0.0.1:8101/', traces[1]['RemoteURL']

      AppOpticsAPM::Config[:httpclient][:log_args] = @log_args
    end

    def test_without_tracing
      clnt = HTTPClient.new
      clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })

      traces = get_all_traces
      # we only get traces from rack
      assert_equal 2, traces.count
      traces.each do |trace|
        assert_equal 'rack', trace["Layer"]
      end

    end
  end
end
