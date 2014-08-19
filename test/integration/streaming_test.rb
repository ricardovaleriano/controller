require 'test_helper'
require 'lotus/action/streaming'
require 'countdownlatch'

describe 'Non blocking ("normal") stream' do
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

  it 'forces the right (default) content type header' do
    response = Rack::MockRequest.new(StreamingAction.new).get('/')
    response.headers['Content-Type'].must_equal 'text/event-stream'
  end

  it 'receives the response streamed in the stream block' do
    response = Rack::MockRequest.new(StreamingAction.new).get('/')
    response.body.must_equal "data: starting\n\ndata: streaming\n\ndata: goodbye!\n\n"
  end

  it 'responds with 200 http status code' do
    response = Rack::MockRequest.new(StreamingAction.new).get('/')
    response.status.must_equal 200
  end
end

describe 'defaults the transport to server sent events' do
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
    response.body.must_equal "data: wow\ndata: such a message\ndata: much multilined\n\n"
  end
end

describe 'blocking stream' do
  class BlockingStreaming
    include Lotus::Action
    include Lotus::Action::Streaming

    attr_reader :streaming
    attr_accessor :outer_latch
    attr_accessor :latch

    def call(params)
      blocking_stream do |out|
        # exposes the stream object and block
        @streaming = out
        @latch.countdown!
        @outer_latch.wait

        # simulates the streaming of two messages followed by a blocking call
        out.write 'starting'
        out.write 'gonna block...'
        @latch.countdown!
        @outer_latch.wait

        # stream one more message after been unblocked, and closes stream
        out.write 'goodbye!'
        out.close
        @latch.countdown!
      end
    end
  end

  class BlockingStreamingLatched
    include Lotus::Action
    include Lotus::Action::Streaming

    def initialize(latch, outer_latch)
      @latch = latch
      @outer_latch = outer_latch
    end

    def call(params)
      blocking_stream do |out|
        out.write 'starting'
        out.write 'gonna block...'
        @latch.countdown!
        @outer_latch.wait
        out.write 'goodbye!'
        out.close
      end
    end
  end

  it 'sends response chuncks in a background thread' do
    # starts a blocking request and waits for the stream object
    action = BlockingStreaming.new
    action.latch = CountDownLatch.new 1
    action.outer_latch = CountDownLatch.new 1
    Thread.new {
      @response = Rack::MockRequest.new(action).get '/'
    }
    action.latch.wait

    # acquires the stream object, so we can inspect it receiving the #write
    # calls.
    stream = action.streaming
    messages = []
    stream.class.send(:define_method, :mock_write, ->(msg) {
      messages << msg
    })
    class << stream
      alias_method :original_write, :write
      alias_method :write, :mock_write
    end

    # Then, wait for the first two messages
    action.outer_latch.countdown!
    action.latch = CountDownLatch.new 1
    action.outer_latch = CountDownLatch.new 1
    action.latch.wait
    messages.must_equal ['starting', 'gonna block...']

    # Now release the (fake) blocking call inside the blocking action
    action.outer_latch.countdown!
    action.latch = CountDownLatch.new 1
    action.latch.wait
    messages.must_equal ['starting', 'gonna block...', 'goodbye!', nil]
  end

  it 'sends a correct response body when calling a blocking code' do
    latch = CountDownLatch.new 1
    outer_latch = CountDownLatch.new 1
    action = BlockingStreamingLatched.new latch, outer_latch
    t = Thread.new {
      @response = Rack::MockRequest.new(action).get '/'
    }
    latch.wait
    outer_latch.countdown!

    t.join
    @response.body.must_equal "data: starting\n\ndata: gonna block...\n\ndata: goodbye!\n\n"
  end
end
