require 'test_helper'
require 'lotus/action/streaming'

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
