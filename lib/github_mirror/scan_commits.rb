require 'json'
require 'shellwords'
require 'set'

module GithubMirror

  class ScanCommits

    def read_git_refs(git_dir)
      # Could / should use git for-each-ref --format "..."
      lines = `cd #{Shellwords.shellescape git_dir} && git for-each-ref`.lines
      lines.reduce({}) do |h, l|
        m = l.match /^(?<commit>\w{40}) (?<type>\S+)\s+(?<ref>.*)$/
        m or raise "Failed to parse for-each-ref line #{l.inspect} in #{git_dir.inspect}"

        entry = {
          "commit" => m["commit"],
          "type" => m["type"],
          "ref" => m["ref"],
        }

        h[ entry["ref"] ] = entry
        h
      end
    end

    def read_old_refs(dir)
      begin
        JSON.parse(IO.read "#{dir}/scanned-refs.json")
      rescue Errno::ENOENT
        {}
      end
    end

    class GitLogParser
      def initialize(io)
        @io = io
      end

      def parse
        commit = []
        file = []
        hunk = []
        buffer = nil

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
              yield commit, file, hunk
            end

            commit = []
            file = []
            hunk = []
            buffer = commit
            buffer << l
            next
          end

          if l.start_with? "diff "
            yield commit, file, hunk unless hunk.empty?
            file = []
            hunk = []
            buffer = file
            buffer << l
            next
          end

          if l.start_with? "@@ "
            yield commit, file, hunk unless hunk.empty?
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
          yield commit, file, hunk
        end

      end
    end

    def scan_new_commits(old_refs, curr_refs, local_dir, git_dir)
      curr_commits = curr_refs.values.map {|r| r["commit"]}
      old_commits = old_refs.values.map {|r| r["commit"]}

      new_commits = curr_commits - old_commits
      old_commits = old_commits - curr_commits
      return [] if new_commits.empty?

      # How many lines apart might the access + secret key be from each other?
      # Let's try 10.
      cmdline = %w[ git log --reverse -U10 -p --cc ]
      cmdline.concat new_commits
      cmdline.concat old_commits.map {|c| "^"+c}
      puts cmdline.join " "

      commits = Set.new
      files = Set.new
      hunks = 0
      interesting_diffs = []

      IO.pipe("ASCII-8BIT") do |r,w|
        pid = Process.spawn(
          *cmdline,
          in: "/dev/null",
          out: w,
          chdir: git_dir,
        )
        w.close

        GitLogParser.new(r).parse do |commit, file, hunk|
          # raise({ commit: commit, file: file, hunk: hunk }.inspect) if commit.empty? or file.empty? or hunk.empty?
          commits << commit.first
          files << (commit.first + file.first) unless file.empty?
          hunks = hunks + 1 unless hunk.empty?

          if hunk.any? {|l| l.match /AKIA/}
            interesting_diffs << {
              commit: commit,
              file: file,
              hunk: hunk,
            }
          end
        end

        Process.waitpid pid
        $?.success? or raise "git log failed"
      end

      puts "  scanned #{commits.size} commits, #{files.size} files, #{hunks} hunks"

      interesting_diffs
    end

    def save_interesting(interesting_diffs, local_dir)
      file = "#{local_dir}/interesting.json"

      d = begin
            JSON.parse(IO.read file)
          rescue Errno::ENOENT
            nil
          end

      if d.nil? or !interesting_diffs.empty?
        d ||= []
        d.concat interesting_diffs

        tmp_file = file+".tmp"
        IO.write tmp_file, JSON.pretty_generate(d)+"\n"
        File.rename tmp_file, file
        IO.write("#{local_dir}/interesting-changed", "")
      end
    end

    def save_new_refs(refs, local_dir)
      file = "#{local_dir}/scanned-refs.json"
      tmp_file = file+".tmp"
      IO.write tmp_file, JSON.pretty_generate(refs)+"\n"
      File.rename tmp_file, file
    end

    def scan_one(changed_file)
      local_dir = File.dirname changed_file
      git_dir = "#{local_dir}/mirror"
      puts local_dir

      curr_refs = read_git_refs git_dir
      old_refs = read_old_refs local_dir

      interesting_diffs = scan_new_commits(old_refs, curr_refs, local_dir, git_dir)

      unless interesting_diffs.empty?
        puts "  #{interesting_diffs.length} interesting new diffs in #{git_dir}"
      end

      save_interesting(interesting_diffs, local_dir)
      save_new_refs(curr_refs, local_dir)
      File.unlink changed_file
    end

    def list_jobs
      Dir.glob("var/github/*/*/mirror-changed").sort
    end

    def run
      list_jobs.each do |changed_file|
        scan_one changed_file
      end
    end

  end

end