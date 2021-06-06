require 'rosarium'
require 'rosarium/ensure'

# Usage:
#   limiter = Rosarium::PromiseConcurrencyLimiter.new(5)
#   promise = limiter.promise { make_a_promise }
#
# Ensures that at most (e.g.) 5 promises are created (and therefore
# potentially execute) at a time.  Probably only really useful if
# the make_a_promise is actually a call to Rosarium::Promise.execute .

class Rosarium::PromiseConcurrencyLimiter

  def initialize(max)
    @remaining = max
    @mutex = Mutex.new
    @queue = []
  end

  def promise(&promise_maker)
    deferred = Rosarium::Promise.defer

    @mutex.synchronize do
      @queue << {
        promise_maker: promise_maker,
        deferred: deferred,
      }
    end

    try_start

    deferred.promise
  end

  private

  def try_start
    to_start = @mutex.synchronize do
      if @remaining > 0 and !@queue.empty?
        @remaining -= 1
        raise if @remaining < 0
        @queue.shift
      end
    end

    start to_start if to_start
  end

  def start(job)
    # Could also rescue here and generate a rejected promise
    promise = job[:promise_maker].call

    promise.ensure do
      @mutex.synchronize { @remaining += 1 }
      try_start
      job[:deferred].resolve promise
    end
  end

end
