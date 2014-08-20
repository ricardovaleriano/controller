require 'test_helper'
require 'lotus/action/streaming'

describe Lotus::Action::Streaming::EventStream do
  it 'call the env["async-callback"] with the right rack response' do
    event_stream = EventStream.new(SSE.new, ->(_) {})
    my_callback = MiniTest::Mock.new
    my_callback.expect :call, nil, [[ 200, {'Content-Type' => 'text/event-stream'}, event_stream ]]
    catch(:async) { event_stream.open({'async.callback' => my_callback}) }
    my_callback.verify
  end

  it 'uses EM.next_tick for nonblock streaming' do
    def EM::next_tick; yield end
    async_code_called = false
    event_stream = EventStream.new(SSE.new, ->(_) { async_code_called = true }, :next_tick)
    catch(:async) { event_stream.open({'async.callback' => ->(_){}}) }
    async_code_called.must_equal true
  end

  it 'uses EM.defer for blocking streaming' do
    def EM::defer; yield end
    async_code_called = false
    event_stream = EventStream.new(SSE.new, ->(_) { async_code_called = true }, :defer)
    catch(:async) { event_stream.open({'async.callback' => ->(_){}}) }
    async_code_called.must_equal true
  end
end
