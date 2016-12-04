module GithubMirror

  class GitLogRunner

    def self.run(git_dir, git_log_opts, include_commits, exclude_commits, &block)
      new_commits = include_commits - exclude_commits
      old_commits = exclude_commits - include_commits
      return if new_commits.empty?

      cmdline = %w[ git log ] + git_log_opts

      # FIXME should use --stdin to pass the commits on stdin, instead of the
      # command line
      cmdline.concat new_commits
      cmdline.concat old_commits.map {|c| "^"+c}

      # puts cmdline.join " "
      # puts "#{git_dir} : #{cmdline.join " "}"

      IO.pipe("ASCII-8BIT") do |r,w|
        pid = Process.spawn(
          *cmdline,
          in: "/dev/null",
          out: w,
          chdir: git_dir,
        )
        w.close

        GitLogParser.new(r).parse(&block)

        Process.waitpid pid
        # Can get stuck here with "bad object", if one of the
        # previously-scanned commits (i.e. in old_refs) no longer exists.
        # Solution for now: manually remove the offending commit hash from
        # scanned-refs.json and re-run.
        $?.success? or raise "git log failed (in #{git_dir})"
      end
    end

  end

end
