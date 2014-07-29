require 'json'

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
        stream = self.body = Stream.new queue, @_env
        sse_buffer = SSE.new stream
        Thread.new { blk.call(sse_buffer) }.abort_on_exception = true
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
        def initialize(queue, env)
          @queue = queue
          @env = env
        end

        def write(msg)
          @queue.push msg
        end

        def each
          if @env['async.callback']
            # event machine stuff here (thin/rainbows...)
          else
            loop { yield @queue.pop }
          end
        end
      end # Streamer

    end
  end
end
