# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

unless defined?(JRUBY_VERSION)
  require 'minitest_helper'
  require 'traceview/inst/rack'
  require File.expand_path(File.dirname(__FILE__) + '../../frameworks/apps/sinatra_simple')

  class HTTPClientTest < Minitest::Test
    include Rack::Test::Methods

    def app
      SinatraSimple
    end

    def setup
      clear_all_traces
      TraceView::Config[:tracing_mode] = :always
    end

    def test_reports_version_init
      init_kvs = ::TraceView::Util.build_init_report
      assert init_kvs.key?('Ruby.httpclient.Version')
      assert_equal ::HTTPClient::VERSION, init_kvs['Ruby.httpclient.Version']
    end

    def test_get_request
      clear_all_traces

      response = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
      end

      traces = get_all_traces

      # Validate returned xtrace
      assert response.headers.key?("X-Trace")
      assert TraceView::XTrace.valid?(response.headers["X-Trace"])

      assert_equal traces.count, 7
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/?keyword=ruby&lang=en'
      assert_equal traces[1]['HTTPMethod'], 'GET'
      assert traces[1].key?('Backtrace')

      assert_equal traces[5]['Layer'], 'httpclient'
      assert_equal traces[5]['Label'], 'exit'
      assert_equal traces[5]['HTTPStatus'], 200
    end

    def test_get_with_header_hash
      clear_all_traces

      response = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', nil, { "SOAPAction" => "HelloWorld" })
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert TraceView::XTrace.valid?(xtrace)

      assert_equal traces.count, 7
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
      assert_equal traces[1]['HTTPMethod'], 'GET'
      assert traces[1].key?('Backtrace')

      assert_equal traces[5]['Layer'], 'httpclient'
      assert_equal traces[5]['Label'], 'exit'
      assert_equal traces[5]['HTTPStatus'], 200
    end

    def test_get_with_header_array
      clear_all_traces

      response = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', nil, [["Accept", "text/plain"], ["Accept", "text/html"]])
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert TraceView::XTrace.valid?(xtrace)

      assert_equal traces.count, 7
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
      assert_equal traces[1]['HTTPMethod'], 'GET'
      assert traces[1].key?('Backtrace')

      assert_equal traces[5]['Layer'], 'httpclient'
      assert_equal traces[5]['Label'], 'exit'
      assert_equal traces[5]['HTTPStatus'], 200
    end

    def test_post_request
      clear_all_traces

      response = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.post('http://127.0.0.1:8101/')
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert TraceView::XTrace.valid?(xtrace)

      assert_equal traces.count, 7
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal traces[1]['IsService'], 1
      assert_equal traces[1]['RemoteURL'], 'http://127.0.0.1:8101/'
      assert_equal traces[1]['HTTPMethod'], 'POST'
      assert traces[1].key?('Backtrace')

      assert_equal traces[5]['Layer'], 'httpclient'
      assert_equal traces[5]['Label'], 'exit'
      assert_equal traces[5]['HTTPStatus'], 200
    end

    def test_async_get
      skip if RUBY_VERSION < '1.9.2'

      clear_all_traces

      conn = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        conn = clnt.get_async('http://127.0.0.1:8101/?blah=1')
      end

      # Allow async request to finish
      Thread.pass until conn.finished?

      traces = get_all_traces
      assert_equal traces.count, 7
      assert valid_edges?(traces), "Invalid edge in traces"

      # FIXME: validate_outer_layers assumes that the traces
      # are ordered which in the case of async, they aren't
      # validate_outer_layers(traces, "httpclient_tests")

      assert_equal 1, traces[2]['Async']
      assert_equal 1, traces[2]['IsService']
      assert_equal 'http://127.0.0.1:8101/?blah=1', traces[2]['RemoteURL']
      assert_equal 'GET', traces[2]['HTTPMethod']
      assert traces[2].key?('Backtrace')

      assert_equal 'httpclient', traces[6]['Layer']
      assert_equal 'exit', traces[6]['Label']
      assert_equal 200, traces[6]['HTTPStatus']
    end

    def test_cross_app_tracing
      clear_all_traces

      response = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
      end

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert TraceView::XTrace.valid?(xtrace)

      traces = get_all_traces

      assert_equal traces.count, 7
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 1, traces[1]['IsService']
      assert_equal 'http://127.0.0.1:8101/?keyword=ruby&lang=en', traces[1]['RemoteURL']
      assert_equal 'GET', traces[1]['HTTPMethod']
      assert traces[1].key?('Backtrace')

      assert_equal 'rack', traces[2]['Layer']
      assert_equal 'entry', traces[2]['Label']
      assert_equal 'rack', traces[3]['Layer']
      assert_equal 'info', traces[3]['Label']
      assert_equal 'rack', traces[4]['Layer']
      assert_equal 'exit', traces[4]['Label']

      assert_equal 'httpclient', traces[5]['Layer']
      assert_equal 'exit', traces[5]['Label']
      assert_equal 200, traces[5]['HTTPStatus']
    end

    def test_requests_with_errors
      clear_all_traces

      result = nil
      begin
        TraceView::API.start_trace('httpclient_tests') do
          clnt = HTTPClient.new
          result = clnt.get('http://asfjalkfjlajfljkaljf/')
        end
      rescue
      end

      traces = get_all_traces
      assert_equal 5, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"
      validate_outer_layers(traces, "httpclient_tests")

      assert_equal 1, traces[1]['IsService']
      assert_equal 'http://asfjalkfjlajfljkaljf/', traces[1]['RemoteURL']
      assert_equal 'GET', traces[1]['HTTPMethod']
      assert traces[1].key?('Backtrace')

      assert_equal 'httpclient', traces[2]['Layer']
      assert_equal 'error', traces[2]['Label']
      assert_equal "SocketError", traces[2]['ErrorClass']
      assert traces[2].key?('ErrorMsg')
      assert traces[2].key?('Backtrace')

      assert_equal 'httpclient', traces[3]['Layer']
      assert_equal 'exit', traces[3]['Label']
    end

    def test_log_args_when_true
      clear_all_traces

      @log_args = TraceView::Config[:httpclient][:log_args]
      TraceView::Config[:httpclient][:log_args] = true

      response = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert TraceView::XTrace.valid?(xtrace)

      assert_equal 7, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"

      assert_equal 'http://127.0.0.1:8101/?keyword=ruby&lang=en', traces[1]['RemoteURL']

      TraceView::Config[:httpclient][:log_args] = @log_args
    end

    def test_log_args_when_false
      clear_all_traces

      @log_args = TraceView::Config[:httpclient][:log_args]
      TraceView::Config[:httpclient][:log_args] = false

      response = nil

      TraceView::API.start_trace('httpclient_tests') do
        clnt = HTTPClient.new
        response = clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
      end

      traces = get_all_traces

      xtrace = response.headers['X-Trace']
      assert xtrace
      assert TraceView::XTrace.valid?(xtrace)

      assert_equal 7, traces.count
      assert valid_edges?(traces), "Invalid edge in traces"

      assert_equal 'http://127.0.0.1:8101/', traces[1]['RemoteURL']

      TraceView::Config[:httpclient][:log_args] = @log_args
    end

    def test_without_tracing
      clear_all_traces

      clnt = HTTPClient.new
      clnt.get('http://127.0.0.1:8101/', :query => { :keyword => 'ruby', :lang => 'en' })
    end
  end
end
