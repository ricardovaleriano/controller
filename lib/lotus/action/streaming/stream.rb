module Lotus
  module Action
    module Streaming
      # Handles the threaded stream mode.
      class Stream
        # @param transport [#call]
        # @param blocking_code [#call] code to be executed in a background thread
        def initialize(transport, blocking_code)
          @transport, @blocking_code = transport, blocking_code
          @queue = Queue.new
        end

        # This starts the streaming opening the transport and executing the
        # blocking code in a non blocking fashion
        #
        # @param env [Hash] the environment rack object
        # @return [Stream] the stream ready to receive writes
        def open(env)
          @transport.open self
          Thread.new {
            @blocking_code.call self
          }.abort_on_exception = true
          self
        end

        def write(message, options = {})
          @queue.push(
            message ? ->(){ @transport.call message, options } : nil
          )
        end

        def each(&async_blk)
          loop do
            message = @queue.pop
            if message
              yield message.call
            else
              break
            end
          end
        end

        def close
          @transport.close self
        end
      end
    end
  end
end
