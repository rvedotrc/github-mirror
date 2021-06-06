# There's actually nothing specific to git about this.
# This is just a wrapper around Process.spawn, where
# stdin is /dev/null, and it turns stdout and stderr as
# strings, and also $?.

class GithubMirror
  class GitCommandRunner

    def self.run(*args)
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
          { out: out.read, err: err.read, status: $? }
        end
      end
    end

    def self.run!(*args)
      r = run *args

      unless r[:status].success?
        raise "#{args.inspect} failed: #{r[:err]} #{r[:out]}"
      end

      r
    end

  end
end
