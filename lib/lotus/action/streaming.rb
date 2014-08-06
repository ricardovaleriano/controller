require 'json'
require 'pp'

module Lotus
  module Action
    module Streaming
      Lotus::Controller.configure do |config|
        format sse: 'text/event-stream'
      end

      protected
      def stream(&blk)
        self.headers.merge! "Cache-Control" => "no-cache"
        self.format = :sse

        queue = Queue.new

        if @_env['async.callback']
          stream = self.body = EventStream.new queue
          sse_buffer = SSE.new stream

          EM.defer { blk.call(sse_buffer) }

          @_env['async.callback'].call [ 200, { 'Content-Type' => 'text/event-stream' }, stream ]
          throw :async
        else
          stream = self.body = Stream.new queue
          sse_buffer = SSE.new stream
          Thread.new { blk.call(sse_buffer) }.abort_on_exception = true
        end
      end

      class SSE
        def initialize(stream)
          @stream = stream
        end

        def write(msg, options = {})
          if event_name = options[:event]
            @stream.write "event: #{event_name}\n"
          end
          unless msg.is_a? String
            msg = JSON.generate msg
          end
          @stream.write "data: #{msg}\n\n"
        end
      end

      class Stream
        def initialize(queue)
          @queue = queue
        end

        def write(msg)
          @queue.push msg
        end

        def each
          loop { yield @queue.pop }
        end
      end # Streamer

      class EventStream
        require 'eventmachine'
        include ::EM::Deferrable

        def initialize(queue)
          @queue = queue
        end

        def write(msg)
          @queue.push msg
        end

        def each(&block)
          EM.defer { loop { yield @queue.pop } }
        end
      end # Streamer

    end
  end
end
