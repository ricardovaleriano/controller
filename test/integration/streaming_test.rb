require 'test_helper'

describe 'Streaming actions' do
  class StreamingAction
    include Lotus::Action
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        out.write 'starting'
        out.write 'streaming'
        out.write 'good bye!'
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

  class BlockingStreaming
    include Lotus::Action
    include Lotus::Action::Streaming

    attr_accessor :latch

    def call(params)
      blocking_stream do |out|
        out.write 'starting'
        out.write 'gonna block...'
        latch.wait
        out.write 'good bye!'
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
        out.write 'good bye!'
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

  describe 'Non blocking ("normal") stream' do
    it 'receives the response streamed in the stream block' do
      response = Rack::MockRequest.new(StreamingAction.new).get('/')
      response.body.must_equal "data: starting\n\ndata: streaming\n\ndata: good bye!\n\n"
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
        @action = Rack::MockRequest.new(StreamingActionWithOptions.new)
      end

      it 'send the id' do
        response = @action.get('/', params: { id: '123' })
        response.body.must_equal "id: 123\ndata: starting\n\n"
      end

      it 'send the event name' do
        response = @action.get('/', params: { event: 'go' })
        response.body.must_equal "event: go\ndata: starting\n\n"
      end

      it 'send the retry'
      it 'send a multiline string as data'
      it 'just ignores unknown options'
    end
  end

  describe 'blocking stream' do

  end
end
