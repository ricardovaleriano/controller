$: << File.expand_path('../../lib', __FILE__)

require 'lotus/controller'
require 'lotus/action/streaming'

class Blocking
  require 'rb-fsevent'

  include Lotus::Action
  include Lotus::Action::Streaming

  def self.call(env)
    new.call(env)
  end

  def call(params)
    blocking_stream do |out|
      out.write 'streaming from lotus!'
      directories = [ File.join(File.expand_path('../', __FILE__)) ]
      fsevent = FSEvent.new
      out.write 'you can push messages at any time...'
      counter = 1
      fsevent.watch(directories) { |dirs|
        counter += 1;
        out.write({dirs: dirs }, event: 'refresh')
        out.close if counter == 10
      }
      fsevent.run
    end
  end
end

class NonBlockingEM
  include Lotus::Action
  include Lotus::Action::Streaming

  def self.call(env)
    new.call(env)
  end

  def call(params)
    stream do |out|
      out.write 'streaming from lotus!'
      EM::add_timer(1) { out.write 'you can push messages at any time...' }
      EM::add_timer(13) {
        out.write 'so 13 seconds has passed since the request, closing...'
        out.close
      }
      (3...8).each do |i|
        EM::add_timer(i) { out.write 'streaming... ' }
      end
    end
  end
end

class NonBlockingEMFS
  require 'listen'

  include Lotus::Action
  include Lotus::Action::Streaming

  def self.call(env)
    new.call(env)
  end

  def call(params)
    stream do |out|
      out.write 'streaming from lotus!'
      directories = [ File.join(File.expand_path('../', __FILE__)) ]
      out.write 'you can push messages at any time...'
      counter = 1
      listener = Listen.to(*directories) { |modified, added, moved|
        counter += 1
        out.write({dirs: modified }, event: 'refresh')
        out.close if counter == 10
      }
      listener.start
    end
  end
end

map('/blocking') { run Blocking }
map('/non_blocking_em') { run NonBlockingEM }
map('/non_blocking_emfs') { run NonBlockingEMFS }
