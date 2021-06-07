class GithubMirror
  class PrefixedLogger

    def initialize(out: $stdout, prefix: '', mutex: nil)
      @out = out
      @prefix = prefix
      @mutex = mutex || Mutex.new
    end

    def nest(prefix)
      self.class.new(out: @out, prefix: @prefix + prefix, mutex: @mutex)
    end

    def puts(message)
      @mutex.synchronize do
        @out.puts(@prefix + message)
      end
    end

  end
end
