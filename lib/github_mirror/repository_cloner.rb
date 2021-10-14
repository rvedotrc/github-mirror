class GithubMirror
  class RepositoryCloner

    attr_reader :ssh_url, :pushed_at, :canonical_dir, :full_name, :meta

    def initialize(ssh_url, pushed_at, canonical_dir, full_name, meta, logger:)
      @ssh_url = ssh_url
      @pushed_at = pushed_at
      @canonical_dir = canonical_dir
      @full_name = full_name
      @meta = meta
      @logger = logger

      require 'github_mirror/git_command_runner'
      @gcr = GitCommandRunner.new(logger: logger)
    end

    def mirror
      if Dir.exists?(target)
        fetch
      else
        clone
      end
    end

    private

    attr_reader :gcr

    def target
      "#{canonical_dir}/#{MIRROR_DIR}"
    end

    def clone
      @logger.puts "clone #{full_name} into #{target}"

      require 'fileutils'
      FileUtils.mkdir_p canonical_dir
      tmp = target + ".tmp"
      FileUtils.rm_rf(target)
      FileUtils.rm_rf(tmp)

      gcr.run(
        "git", "clone",
        "--bare",
        "--config", 'remote.origin.fetch=+refs/*:refs/origin/*',
        ssh_url, tmp,
        uses_remote: true,
      )

      File.rename tmp, target

      meta.set(:mirror, :last_fetched_at, pushed_at)
    end

    def fetch
      return if meta.get(:mirror, :last_fetched_at) == pushed_at

      @logger.puts "git fetch #{full_name} => #{canonical_dir}"
      do_fetch

      meta.set(:mirror, :last_fetched_at, pushed_at)
    end

    def do_fetch
      # In case it's been renamed
      gcr.run("git", "--git-dir", target, "config", "remote.origin.url", ssh_url)

      r = gcr.run(
        "git", "--git-dir", target, "fetch", "--prune",
        uses_remote: true,
        catch: -> (r2) do
          if r2[:out].match(/\Afatal: Couldn't find remote ref HEAD\n*\z/)
            r2[:empty_repo] = true
            r2[:status] = Struct.new(:success?).new(true)
          end

          r2
        end,
      )

      if r[:empty_repo]
        @logger.puts "#{full_name} is an empty repository"
        return
      end

      r[:out].each_line { |line| @logger.puts(line) }
      r[:err].each_line { |line| @logger.puts(line) }
    end

  end
end
