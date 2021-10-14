# There's actually nothing specific to git about this.
# This is just a wrapper around Process.spawn, where
# stdin is /dev/null, and it turns stdout and stderr as
# strings, and also $?.

class GithubMirror
  class GitCommandRunner

    def self.run(*args)
      new.run(*args)
    end

    def self.run!(*args)
      new.run!(*args)
    end

    def initialize(logger: nil)
      logger ||= PrefixedLogger.new
      @logger = logger
    end

    def run(*args)
      require 'tempfile'

      sleep_duration = 1.0

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

          if answer[:err].match(/fatal: Could not read from remote repository|fatal: The remote end hung up unexpectedly/)
            if sleep_duration < 60
              sleep_duration *= 1.5
            end
            answer[:err].each_line.map(&:chomp).each {|t| @logger.puts t }
            @logger.puts "Could not read from remote repository - will wait #{sleep_duration.ceil}s and retry"
            sleep sleep_duration
            @logger.puts "Trying again"

            out.rewind
            err.rewind
            out.truncate(0)
            err.truncate(0)
            redo
          end

          # puts "#{args.inspect} => #{answer.inspect}"
          answer
        end
      end
    end

    def run!(*args)
      r = run *args

      unless r[:status].success?
        raise "#{args.inspect} failed: #{r[:err]} #{r[:out]}"
      end

      r
    end

  end
end
