# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe 'UTF8Sanitizer middleware' do
  describe 'parameter sanitization' do
    it 'sanitizes invalid UTF-8 byte sequences' do
      sanitizer = Rack::UTF8Sanitizer.new(proc { |env| [ 200, {}, [ 'OK' ] ] })

      env = {
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/test',
        'QUERY_STRING' => "key=value\xFF\xFE&valid=ok"
      }

      expect { sanitizer.call(env) }.not_to raise_error

      expect(env['QUERY_STRING']).not_to include("\xFF\xFE")
    end

    it 'preserves valid UTF-8 characters' do
      sanitizer = Rack::UTF8Sanitizer.new(proc { |env| [ 200, {}, [ 'OK' ] ] })

      env = {
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/test',
        'QUERY_STRING' => 'key=valid&unicode=café'
      }

      sanitizer.call(env)

      expect(env['QUERY_STRING']).to include('key=valid')
      expect(env['QUERY_STRING']).to include('unicode=')
    end
  end
end
