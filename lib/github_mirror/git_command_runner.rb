# There's actually nothing specific to git about this.
# This is just a wrapper around Process.spawn, where
# stdin is /dev/null, and it turns stdout and stderr as
# strings, and also $?.

class GithubMirror
  class GitCommandRunner

    @mutex = Mutex.new
    @sleep_duration = 1.0

    def self.remote_rate_limit(logger)
      loop do
        answer = yield

        fail = !answer[:status].success? && answer[:err].match(/fatal: Could not read from remote repository|fatal: The remote end hung up unexpectedly/)

        if fail
          this_sleep = @mutex.synchronize do
            if @sleep_duration < 60
              @sleep_duration *= 1.5
            end
          end

          answer[:err].each_line.map(&:chomp).each {|t| @logger.puts t }
          logger.puts "Could not read from remote repository - will wait #{this_sleep.ceil}s and retry"
          sleep this_sleep
          logger.puts "Trying again"

          redo
        end

        @mutex.synchronize do
          if @sleep_duration >= 2.0
            @sleep_duration /= 2.0
          end
        end

        break answer
      end
    end

    def initialize(logger: nil)
      logger ||= PrefixedLogger.new
      @logger = logger
    end

    def run(*args)
      require 'tempfile'

      Tempfile.open do |out|
        Tempfile.open do |err|
          args = args.dup
          args << {} unless args.last.kind_of? Hash
          args[-1] = args[-1].dup

          args.last.merge!(
            in: '/dev/null',
            out: out,
            err: err,
          )

          pid = Process.spawn(*args)
          Process.wait pid

          out.rewind
          err.rewind

          answer = { out: out.read, err: err.read, status: $? }
          # puts "#{args.inspect} => #{answer.inspect}"
          answer
        end
      end
    end

    def remote_rate_limit(&block)
      self.class.remote_rate_limit(@logger, &block)
    end

    def raise_on_error
      r = yield

      unless r[:status].success?
        # but with what args?
        raise "git failed: #{r[:err]} #{r[:out]}"
      end

      r
    end

  end
end
