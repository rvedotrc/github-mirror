require 'json'
require 'shellwords'
require 'set'

module GithubMirror

  class ScanCommits

    def read_old_refs(dir)
      begin
        JSON.parse(IO.read "#{dir}/scanned-refs.json")
      rescue Errno::ENOENT
        {}
      end
    end

    def scan_new_commits(old_refs, curr_refs, local_dir, git_dir)
      curr_commits = curr_refs.values.map {|r| r["commit"]}
      old_commits = old_refs.values.map {|r| r["commit"]}

      new_commits = curr_commits - old_commits
      old_commits = old_commits - curr_commits
      return [] if new_commits.empty?

      # --reverse - show in chronological order
      # -p -U10 - patch in unified diff format, 10 lines of context
      # --cc - suppress uninteresting merges (where one of two parents is picked)

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
        # Can get stuck here with "bad object", if one of the
        # previously-scanned commits (i.e. in old_refs) no longer exists.
        # Solution for now: manually remove the offending commit hash from
        # scanned-refs.json and re-run.
        $?.success? or raise "git log failed (in #{git_dir})"
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

      curr_refs = GitRefReader.read_git_refs git_dir
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
