require 'test_helper'
require 'lotus/action/streaming'

describe Lotus::Action::Streaming::EventStream do
  class StreamingAction
    include Lotus::Action
    include Lotus::Action::Streaming
    def call(params); stream end
  end

  before do
    @event_stream = EventStream.new(SSE.new, ->() {})
  end

  it 'call the env["async-callback"] with the right rack response' do
    my_callback = MiniTest::Mock.new
    my_callback.expect :call, nil, [[ 200, {'Content-Type' => 'text/event-stream'}, @event_stream ]]
    catch(:async) { @event_stream.open({'async.callback' => my_callback}) }
    my_callback.verify
  end

  it 'uses EM.event_tick for nonblock streaming'
  it 'uses EM.defer for blocking streaming'
end
