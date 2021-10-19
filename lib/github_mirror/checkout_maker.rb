class GithubMirror
  class CheckoutMaker

    attr_reader :ssh_url, :canonical_dir, :meta, :default_branch

    def initialize(ssh_url, canonical_dir, meta, default_branch, logger:)
      @ssh_url = ssh_url
      @canonical_dir = canonical_dir
      @meta = meta
      @default_branch = default_branch
      @logger = logger

      @mirror_dir = File.join(canonical_dir, MIRROR_DIR)
      @checkout_dir = File.join(canonical_dir, CHECKOUT_DIR)

      require 'github_mirror/git_command_runner'
      @gcr = GitCommandRunner.new(logger: @logger)
    end

    def mirror
      t = meta.get(:mirror, :last_fetched_at)
      t or return

      if !File.exist?(@checkout_dir)
        clone
        meta.set(:checkout, :last_pulled_at, t)
      else
        if meta.get(:checkout, :last_pulled_at) != t
          pull
          meta.set(:checkout, :last_pulled_at, t)
        end
      end
    end

    private

    attr_reader :logger, :mirror_dir, :checkout_dir, :gcr

    def clone
      gcr.run(
        "git",
        "clone",
        "--reference", MIRROR_DIR,
        @ssh_url,
        CHECKOUT_DIR,
        chdir: canonical_dir,
      )
    end

    def pull
      # In case it's been renamed
      gcr.run("git", "config", "remote.origin.url", ssh_url, chdir: @checkout_dir)

      gcr.run("git", "fetch", "--prune", chdir: @checkout_dir, uses_remote: true)

      unless clean?
        raise "Refusing to 'git checkout' in #{@checkout_dir} because of non-clean status"
      end

      gcr.run("git", "checkout", "origin/#{default_branch}", chdir: @checkout_dir)
    end

    def clean?
      result = gcr.run("git", "status", "--porcelain", chdir: @checkout_dir)
      return true if result.out == ""

      files = gcr.run("git", "ls-files", "-z", chdir: @checkout_dir).out.split("\0")

      # If we're in case-sensitivity hell, just pretend everything is fine.
      # (It could simply be that file 'Foo' and 'foo' are conflicting, and therefore
      # always showing as "locally" modified).
      if files.count != files.map(&:downcase).uniq.count
        logger.puts "Ignoring cleanness check because of case clash (may be impossible to check out cleanly)"
        return true
      end

      false
    end

  end
end
