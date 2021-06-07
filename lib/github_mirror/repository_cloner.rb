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
    end

    def mirror
      if Dir.exists?(target)
        fetch
      else
        clone
      end
    end

    private

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

      system "git", "clone",
        "--bare",
        "--config", 'remote.origin.fetch=+refs/*:refs/origin/*',
        ssh_url, tmp
      $?.success? or raise "git clone #{full_name} failed"

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
      require 'github_mirror/git_command_runner'
      GitCommandRunner.run!("git", "--git-dir", target, "config", "remote.origin.url", ssh_url)

      require 'tempfile'
      Tempfile.open do |t|
        Process.wait(Process.spawn(
          "git", "--git-dir", target, "fetch", "--prune",
          out: t,
          err: t,
        ))
        t.rewind

        t.each_line { |line| @logger.puts(line) }
        next if $?.success?

        t.rewind
        log = t.read

        if log.match(/\Afatal: Couldn't find remote ref HEAD\n*\z/)
          @logger.puts "#{full_name} is an empty repository"
          next
        end

        raise "git fetch #{full_name} failed: #{log}"
      end
    end

  end
end
