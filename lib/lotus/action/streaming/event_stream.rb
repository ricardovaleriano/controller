module Lotus
  module Action
    module Streaming
      # Evented servers (like Thin, Rainbows and others) use Event Machine to
      # allow non blocking calls. This is the "evented part" of the
      # Lotus::Action::Streaming implementation.
      class EventStream
        include ::EM::Deferrable if defined? ::EM::Deferrable
        # Allows a client to stream data from an action inside a evented server
        #
        # @see Lotus::Action::Streaming::Stream
        #
        # @param transport [<#open, #call, #close>] a transformation that should be done on the message before it is send to the client (via streaming)
        # @param async_code [#call] the proc passed as block to the #stream method
        # @param scheduler [Symbol] the EM strategy to schedulling the async_code invocation
        def initialize(transport, async_code, scheduler = :next_tick)
          @transport, @async_code = transport, async_code
          @scheduler = scheduler
        end

        # Sends the early http response with status 200, and makes sure that a
        # connection with the client will be open after the response header is
        # sent.
        #
        # Also notifies the transport received in the initializer that a
        # connection is ready to be used.
        #
        # TODO: get rid of the `thrown :async` in favor of simply use the
        # ::EM::Defferable object as the response body.
        #
        # @param env [Hash] Rack environment
        def open(env)
          @transport.open self
          response = [ 200, { 'Content-Type' => @transport.class.content_type }, self ]
          env['async.callback'].call response
          EM::__send__(@scheduler) { @async_code.call self }
          throw :async
        end

        # Uses the transport passed in the initializer to transform a message
        # and. Then yield it to the block passed to each (called by rack).
        #
        # If the message is a nil value, it will consider that the connection
        # need to be closed.
        def write(message, options = {})
          EM::next_tick do
            if message
              @async_blk.call(
                @transport.call message, options
              )
            else
              succeed
            end
          end
        end

        def each(&async_blk)
          @async_blk = async_blk
        end

        def close
          @transport.close self
        end
      end
    end
  end
end
