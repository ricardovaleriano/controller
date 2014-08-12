require 'test_helper'

describe 'Streaming actions' do
  class StreamingAction
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        out.write "starting"
        out.write "streaming"
        out.write "good bye!"
        out.close
      end
    end
  end

  class BlockingStreaming
    include Lotus::Action
    include Lotus::Action::Streaming

    attr_accessor :latch

    def call(params)
      blocking_stream do |out|
        out.write "starting"
        out.write "gonna block..."
        latch.wait
        out.write "good bye!"
        out.close
      end
    end
  end

  class LeftOpenStreaming
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        out.write "starting"
        out.write "streaming"
        out.write "good bye!"
      end
    end
  end

  describe 'Non blocking ("normal") stream' do
    it 'receives the response streamed in the stream block' do
      response = Rack::MockRequest.new(StreamingAction.new).get('/')
      response.body.must_equal "data: starting\n\ndata: streaming\n\ndata: good bye!\n\n"
    end

    it 'forces the right http header based on the transport'
    it 'responds with 200 http status code'
    it 'closes an uninteded left open stream'

    describe 'defaults to server sent events' do
      it 'send the id'
      it 'send the event name'
      it 'send the retry'
    end
  end

  describe 'blocking stream' do

  end
end
