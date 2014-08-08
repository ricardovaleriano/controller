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
end
