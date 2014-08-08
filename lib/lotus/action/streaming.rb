require 'json'

module Lotus
  module Action
    module Streaming
      Lotus::Controller.configure do |config|
        format sse: 'text/event-stream'
      end

      class SSE
        def content_type; 'text/event-stream' end
        def format; :sse end
        def open(stream); nil end
        def close(stream); nil end

        def call(message, options = {})
          event, id = options.fetch(:event, nil), options.fetch(:id, nil)
          message = JSON.generate(message) unless message.is_a? String
          construct_message message, id, event
        end

        private

        def construct_message(message, id, event)
          final_message = ""
          final_message << "id: #{id}\n" if id
          final_message << "event: #{event}\n" if event
          final_message << "data: #{message}\n\n"
        end
      end

      class QueueStream
        def initialize(transport = ->(msg, _){ msg }, blocking_code)
          @transport = transport
          @blocking_code = blocking_code
        end

        def queue
          raise "You need to return an #push & #pop object"
        end

        def open(env)
          raise "You need to know how to open the `request...`"
        end

        def write(message, options = {})
          queue.push(
            @transport.call message, options
          )
        end

        def each(&async_blk)
          @async_blk = async_blk
          consume
        end

        def close
          @transport.close self
        end

        private

        def consume
          raise "You need to implement the #queue consumer logic"
        end
      end

      class BlockingEventStream < QueueStream
        include ::EM::Deferrable if require 'eventmachine'

        def open(env)
          @transport.open self
          response = [ 200, { 'Content-Type' => @transport.content_type }, self ]
          env['async.callback'].call response
          EM::defer { @blocking_code.call self }
          throw :async
        end

        def queue
          @queue ||= ::EM::Queue.new
        end

        private

        def consume
          front = ->(msg) {
            @async_blk.call msg
            ::EM::add_timer(0.006) { queue.pop(&front) }
          }
          queue.pop(&front)
        end
      end

      class Stream < QueueStream
        def open(env)
          @transport.open self
          Thread.new { @blocking_code.call self }.abort_on_exception = true
          self
        end

        def queue
          @queue ||= Queue.new
        end

        private

        def consume
          loop {
            message = @queue.pop
            @async_blk.call message
          }
        end
      end

      class EventStream
        include ::EM::Deferrable

        def initialize(transport = ->(msg, _){ msg }, async_code)
          @transport = transport
          @async_code = async_code
        end

        def write(message, options = {})
          EM::next_tick {
            @async_blk.call(
              @transport.call message, options
            )
          }
        end

        def each(&async_blk)
          @async_blk = async_blk
        end

        def open(env)
          @transport.open self
          response = [ 200, { 'Content-Type' => @transport.content_type }, self ]
          env['async.callback'].call response
          EM::next_tick { @async_code.call self }
          throw :async
        end

        def close
          @transport.close self
        end
      end

      protected

      def stream(options = {}, &blk)
        transport = options.fetch :transport, SSE.new
        raise 'noooo... invalid transport' unless transport.respond_to? :call

        self.headers['Cache-Control'] = 'no-cache'
        self.headers['Content-Type']  = transport.content_type
        self.format = transport.format

        will_block = options.fetch(:will_block, false)
        self.body = open_stream will_block, transport, blk
      end

      private

      def stream_class(will_block)
        if @_env['async.callback']
          will_block ? BlockingEventStream : EventStream
        else
          Stream
        end
      end

      def open_stream(will_block, transport, blk)
        stream = stream_class(will_block).new(transport, blk)
        stream.open @_env
      end
    end
  end
end
