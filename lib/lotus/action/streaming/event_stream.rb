module Lotus
  module Action
    module Streaming
      class EventStream
        include ::EM::Deferrable if defined? ::EM::Deferrable

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
