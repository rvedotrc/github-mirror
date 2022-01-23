# There's actually nothing specific to git about this.
# This is just a wrapper around Process.spawn, where
# stdin is /dev/null, and it turns stdout and stderr as
# strings, and also $?.

class GithubMirror
  class GitCommandRunner

    Result = Struct.new(
      :out, :err, :exitstatus, :success?, :error_tag,
      keyword_init: true
    )

    @mutex = Mutex.new
    @sleep_duration = 1.0

    def self.adjust(failed:)
      adjustment = failed ? 1.5 : 0.5
      @mutex.synchronize do
        answer = @sleep_duration
        @sleep_duration = @sleep_duration * adjustment
        @sleep_duration = [@sleep_duration, 1.0].max
        @sleep_duration = [@sleep_duration, 60.0].min
        answer
      end
    end

    def self.remote_rate_limit(logger)
      loop do
        answer = yield

        # clone-all zendesk/viticult checkout kex_exchange_identification: read: Connection reset by peer
        # clone-all zendesk/viticult checkout fatal: Could not read from remote repository.
        # clone-all zendesk/viticult checkout
        # clone-all zendesk/viticult checkout Please make sure you have the correct access rights
        # clone-all zendesk/viticult checkout and the repository exists.
        # clone-all zendesk/viticult checkout Could not read from remote repository - will wait 58s and retry

        # clone-all zendesk/zendesk_protobuf_schemas checkout kex_exchange_identification: Connection closed by remote host
        # clone-all zendesk/zendesk_protobuf_schemas checkout fatal: Could not read from remote repository.
        # clone-all zendesk/zendesk_protobuf_schemas checkout
        # clone-all zendesk/zendesk_protobuf_schemas checkout Please make sure you have the correct access rights
        # clone-all zendesk/zendesk_protobuf_schemas checkout and the repository exists.
        # clone-all zendesk/zendesk_protobuf_schemas checkout Could not read from remote repository - will wait 2s and retry

        fail = !answer.success? && answer.err.match(/kex_exchange_identification/)

        if fail
          this_sleep = adjust(failed: true)

          answer.err.each_line.map(&:chomp).each {|t| logger.puts t }
          logger.puts "Could not read from remote repository - will wait #{this_sleep.ceil}s and retry"
          sleep this_sleep
          logger.puts "Trying again"

          redo
        end

        adjust(failed: false)

        break answer
      end
    end

    def initialize(logger: nil)
      logger ||= PrefixedLogger.new
      @logger = logger
    end

    def run(*args)
      opts = if args.last.is_a?(Hash)
               args.last
             else
               {}
             end

      uses_remote = opts.delete(:uses_remote)
      catch = opts.delete(:catch)

      r = if uses_remote
            self.class.remote_rate_limit(logger) { run_plain(*args) }
          else
            run_plain(*args)
          end

      if catch && !r.success?
        r = catch.call(r)
      end

      if !r.success?
        raise "git #{args} failed: #{r.err} #{r.out}"
      else
        r
      end
    end

    private

    attr_reader :logger

    def run_plain(*args)
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

          answer = Result.new(
            out: out.read,
            err: err.read,
            exitstatus: $?.exitstatus,
            success?: $?.success?,
          )
          # puts "#{args.inspect} => #{answer.inspect}"
          answer
        end
      end
    end

  end
end
