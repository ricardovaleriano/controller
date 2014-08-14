require 'test_helper'
require 'lotus/action/streaming'

require 'countdownlatch'

describe 'Streaming actions' do
  class StreamingAction
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        out.write 'starting'
        out.write 'streaming'
        out.write 'goodbye!'
        out.close
      end
    end
  end

  class StreamingActionWithOptions
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        out.write 'starting', params.params
        out.close
      end
    end
  end

  class LeftOpenStreaming
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        out.write 'starting'
        out.write 'streaming'
        out.write 'goodbye!'
      end
    end
  end

  class StreamingError
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        raise 'OMG!'
      end
    end
  end

  class StreamingMultilineString
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        out.write "wow\nsuch a message\nmuch multilined"
        out.close
      end
    end
  end

  describe 'Non blocking ("normal") stream' do
    it 'receives the response streamed in the stream block' do
      response = Rack::MockRequest.new(StreamingAction.new).get('/')
      response.body.must_equal "data: starting\n\ndata: streaming\n\ndata: goodbye!\n\n"
    end

    it 'forces the right (default) content type header' do
      response = Rack::MockRequest.new(StreamingAction.new).get('/')
      response.headers['Content-Type'].must_equal 'text/event-stream'
    end

    it 'responds with 200 http status code' do
      response = Rack::MockRequest.new(StreamingAction.new).get('/')
      response.status.must_equal 200
    end

    it 'closes an uninteded left open stream'
    it 'recovers from exception during the streaming'

    describe 'defaults the transport to server sent events' do
      before do
        @action = Rack::MockRequest.new StreamingActionWithOptions.new
      end

      it 'send the id' do
        response = @action.get('/', params: { id: '123' })
        response.body.must_equal "id: 123\ndata: starting\n\n"
      end

      it 'send the event name' do
        response = @action.get('/', params: { event: 'go' })
        response.body.must_equal "event: go\ndata: starting\n\n"
      end

      it 'send the retry' do
        response = @action.get('/', params: { retry: '10000' })
        response.body.must_equal "retry: 10000\ndata: starting\n\n"
      end

      it 'just ignores unknown options' do
        response = @action.get('/', params: { omg_not_sse: 'invalid' })
        response.body.must_equal "data: starting\n\n"
      end

      it 'send a multiline string as data' do
        action = Rack::MockRequest.new StreamingMultilineString.new
        response = action.get('/')
        response.body.must_equal "data: wow\ndata: such a message\n data: much multilined\n\n"
      end
    end
  end

  class BlockingStreaming
    include Lotus::Action
    include Lotus::Action::Streaming

    def initialize
    end

    def call(params)
      blocking_stream do |out|
        # I'm in a new thread, external latch release
        out.write 'starting'
        out.write 'gonna block...'
        # Internal latch block, to be released later outside
        #   after the assertion to be sure that two writes have been made.
        #   after release, check if the final write is made.
        out.write 'goodbye!'
        out.close
      end
    end
  end

  describe 'blocking stream' do
    it 'send response chuncks in a background thread'
  end
end
