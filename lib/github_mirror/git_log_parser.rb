module GithubMirror

  class GitLogParser
    def initialize(io)
      @io = io
    end

    def parse
      commit = []
      file = []
      hunk = []
      buffer = nil

      do_yield = Proc.new do
        yield commit_lines: commit, file_lines: file, hunk_lines: hunk
      end

      # Not correct (e.g. a perfectly valid "£" becomes 0xC2 0xA3 becomes \uFFFD uFFFD)
      # but does at least allow the program to run without crashing.  Only
      # acceptable because all the data we care about is ASCII.
      converter = Encoding::Converter.new("ASCII-8BIT", "UTF-8", invalid: :replace, undef: :replace)

      @io.each_line do |l8bit|
        l = converter.convert(l8bit)
        # puts ">> #{l}"

        if l.start_with? "commit "
          # flush whatever we have
          unless commit.empty? and file.empty? and hunk.empty?
            do_yield.call
          end

          commit = []
          file = []
          hunk = []
          buffer = commit
          buffer << l
          next
        end

        if l.start_with? "diff "
          do_yield.call unless hunk.empty?
          file = []
          hunk = []
          buffer = file
          buffer << l
          next
        end

        if l.start_with? "@@ "
          do_yield.call unless hunk.empty?
          hunk = []
          buffer = hunk
          buffer << l
          next
        end

        raise "git-log parse error" if buffer.nil?
        buffer << l
      end

      # flush whatever we have
      unless commit.empty? and file.empty? and hunk.empty?
        do_yield.call
      end

    end

  end

end
