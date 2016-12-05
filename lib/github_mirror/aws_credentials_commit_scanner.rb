require 'json'

module GithubMirror

  class AwsCredentialsCommitScanner

    attr_reader :local_dir, :json_cache, :analyser

    def initialize(local_dir)
      @local_dir = local_dir
      @json_cache = JSONCache.new("#{local_dir}/aws-credentials-commits.json", nil)
      @analyser = AnalyseCommits.new
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
      puts "AwsCredentialsCommitScanner #{local_dir}"

      hashes_before = state["scanned_commits"] || []
      hashes_after = get_commit_hashes

      log = enum_for(:each_interesting_log, hashes_before, hashes_after).to_a

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

    def each_interesting_log(hashes_before, hashes_after)
      GitLogRunner.run(git_dir, %w[ --reverse --date=iso-strict -U10 --cc -GAKIA ], hashes_after, hashes_before) do |found|
        if m = extract_possible_secrets(found)
          r = {
            commit_lines: found[:commit_lines],
            file_lines: found[:file_lines],
            possible_secrets: m,
          }
          yield r
        end
      end
    end

    def extract_possible_secrets(found)
      # nil if nothing found
      # otherwise e.g. { access_key_id: [], secret_access_key: [] }

      unless analyser.interesting? found[:file_lines]
        nil
      end

      analyser.analyse(found[:commit_lines], found[:file_lines], found[:hunk_lines])
    end

  end

end
