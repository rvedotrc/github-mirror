require 'json'

module GithubMirror

  class SwearyCommitScanner

    attr_reader :local_dir, :json_cache

    def initialize(local_dir)
      @local_dir = local_dir
      @json_cache = JSONCache.new("#{local_dir}/sweary-commits.json", 1E9)
    end

    def run
      state = json_cache.read || {}
      pushed_at = IO.read("#{local_dir}/pushed_at")

      unless state["pushed_at"] == pushed_at
        scan state
        state["pushed_at"] = pushed_at
        json_cache.write state
      end

      state
    end

    private

    def git_dir
      "#{local_dir}/mirror"
    end

    def scan(state)
      $stdout.write "SwearyCommitScanner #{local_dir}\n"

      hashes_before = state["scanned_commits"] || []
      hashes_after = get_commit_hashes

      log = enum_for(:each_sweary_log, hashes_before, hashes_after).to_a

      state["scanned_commits"] = hashes_after
      state["log"] ||= []
      state["log"].concat log
    end

    def get_commit_hashes
      # Ignore "pull"; there can be huge numbers of pull refs,
      # which (for now) breaks the maximum command line length.
      # "Pull" commits should show up in (e.g.) master when merged.
      GitRefReader.read_git_refs(git_dir).values.reject {|v| v["ref"].match /^refs\/pull\/\d+\//}.map {|v| v["commit"]}.sort.uniq
    end

    def each_sweary_log(hashes_before, hashes_after)
      GitLogRunner.run(git_dir, %w[ --reverse --date=iso-strict ], hashes_after, hashes_before) do |found|
        m = extract_message found[:commit_lines]
        if is_sweary?(m)
          yield found[:commit_lines]
        end
      end
    end

    def extract_message(commit_lines)
      i = commit_lines.index "\n"
      i or return []
      commit_lines[i+1 .. -1]
    end

    def is_sweary?(m)
      # The Scunthorpe problem, but this is only for fun anyway
      m.join("").match /(fuck|shit|(?<!p|ch)arse(?!t|nal)|wank|bollo|cunt(?!horpe)|toss|piss)/i
    end

  end

end
