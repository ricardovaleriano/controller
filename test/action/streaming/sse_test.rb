require 'test_helper'
require 'lotus/action/streaming'

include Lotus::Action::Streaming
describe Lotus::Action::Streaming::SSE do

  describe '.content_type' do
    it 'returns the event stream http content type' do
      SSE.content_type.must_equal 'text/event-stream'
    end
  end

  describe '.format' do
    it 'returns the format to be associated with the content type' do
      SSE.format.must_equal :sse
    end
  end

  describe '#call' do
    before do
      @sse = SSE.new
    end

    it 'formats prepends the message with data and append \n\n to it' do
      @sse.call('wow').must_equal "data: wow\n\n"
    end

    it 'converts hashes to json formated messages' do
      @sse.call(message: 'such a framework').must_equal "data: {\"message\":\"such a framework\"}\n\n"
    end

    it 'prepends the id to the data message when one is given' do
      stream_message = "id: wow\ndata: much streaming\n\n"
      @sse.call('much streaming', id: 'wow').must_equal stream_message
    end

    it 'prepends the event name when it is passed as option' do
      stream_message = "event: stream_babe\ndata: much streaming\n\n"
      @sse.call('much streaming', event: 'stream_babe').must_equal stream_message
    end

    it 'prepends id and event name in the same message' do
      stream_message = "id: wow\nevent: stream_babe\ndata: much streaming\n\n"
      @sse.call('much streaming', id: 'wow', event: 'stream_babe').must_equal stream_message
    end

    it 'prepends a retry value to the message' do
      stream_message = "retry: 10000\ndata: much streaming\n\n"
      @sse.call('much streaming', retry: '10000').must_equal stream_message
    end
  end
end
