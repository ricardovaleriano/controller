require 'test_helper'
require 'lotus/action/streaming'

describe Lotus::Action::Streaming::EventStream do
  describe '#open' do
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

  describe '#write' do
    class EM::Spec
      def initialize
        @done = false
      end
      def done; @done = true end
      def done?; @done end

      def run
        EM::run {
          spec_loop = ->() {
            if done?
              EM::stop
            else
              EM::add_timer(0.05, &spec_loop)
            end
          }
          spec_loop.call
        }
      end
    end

    it 'uses the transport to transform the chuncks yielded to the each block' do
      emspec = EM::Spec.new
      event_stream = EventStream.new(->(message, options) { message.upcase }, ->(_) {})
      event_stream.each { |chunck|
        chunck.must_equal 'WORD'
        emspec.done
      }
      event_stream.write 'word'

      emspec.run
    end

    it 'repasses the options hash to the transport' do
      emspec = EM::Spec.new
      transport = ->(message, options) {
        options[:omg].must_equal 'such a transport'
        emspec.done
      }
      event_stream = EventStream.new(transport, ->(_) {})
      event_stream.each { |_| _ }
      event_stream.write 'word', omg: 'such a transport'

      emspec.run
    end

    it 'calls #succeed when receives a nil message' do
      emspec = EM::Spec.new
      event_stream = EventStream.new(->(_, _){}, ->(_) {})
      event_stream.callback { emspec.done }
      event_stream.write nil
      emspec.run
    end
  end
end
