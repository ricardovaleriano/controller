require 'json'

module Lotus
  module Action
    module Streaming
      class SSE
        def self.content_type; 'text/event-stream' end
        def self.format; :sse; end
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

      KNOWN_TRANSPORTS = [ SSE ]

      Lotus::Controller.configure do |config|
        KNOWN_TRANSPORTS.each do |transport_type|
          format transport_type.format => transport_type.content_type
        end
      end

      class Stream
        def initialize(transport, blocking_code)
          @transport, @blocking_code = transport, blocking_code
          @queue = Queue.new
        end

        def open(env)
          @transport.open self
          Thread.new { @blocking_code.call self }.abort_on_exception = true
          self
        end

        def write(message, options = {})
          @queue.push(
            @transport.call message, options
          )
        end

        def each(&async_blk)
          loop {
            message = @queue.pop
            # break unless message
            yield message
          }
          close
        end

        def close
          @transport.close self
        end
      end

      class EventStream
        require 'eventmachine'
        include ::EM::Deferrable

        def initialize(transport, async_code, scheduler = :next_tick)
          @transport, @async_code = transport, async_code
          @scheduler = scheduler
        end

        def open(env)
          @transport.open self
          response = [ 200, { 'Content-Type' => @transport.class.content_type }, self ]
          env['async.callback'].call response
          EM::send(@scheduler) { @async_code.call self }
          throw :async
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

        def close
          @transport.close self
        end
      end

      protected

      def stream(options = {}, &blk)
        transport = prepare_for_transport options.fetch(:transport, SSE)
        will_block = options.fetch(:will_block, false)
        stream = new_stream will_block, transport, blk
        self.body = stream.open @env
      end

      private

      def prepare_for_transport(transport_type)
        transport = transport_type.new
        raise 'noooo... invalid transport' unless transport.respond_to? :call

        self.headers['Cache-Control'] = 'no-cache'
        self.headers['Content-Type']  = transport_type.content_type
        self.format = transport_type.format
        transport
      end

      def new_stream(will_block, transport, blk)
        if @_env['async.callback']
          scheduler = will_block ? :defer : :next_tick
          EventStream.new transport, blk, scheduler
        else
          Stream.new transport, blk
        end
      end
    end
  end
end
