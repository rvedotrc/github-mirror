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

    attr_reader :mirror_dir, :checkout_dir, :gcr

    def clone
      system(
        "git",
        "clone",
        "--reference", MIRROR_DIR,
        @ssh_url,
        CHECKOUT_DIR,
        chdir: canonical_dir,
      )
      $?.success? or raise
    end

    def pull
      # In case it's been renamed
      gcr.raise_on_error do
        gcr.run("git", "config", "remote.origin.url", ssh_url, chdir: @checkout_dir)
      end

      gcr.raise_on_error do
        gcr.remote_rate_limit do
          gcr.run("git", "fetch", "--prune", chdir: @checkout_dir)
        end
      end

      unless clean?
        raise "Refusing to 'git checkout' in #{@checkout_dir} because of non-clean status"
      end

      gcr.raise_on_error do
        gcr.run("git", "checkout", "origin/#{default_branch}", chdir: @checkout_dir)
      end
    end

    def clean?
      result = gcr.raise_on_error do
        gcr.run("git", "status", "--porcelain", chdir: @checkout_dir)
      end

      result[:out] == ""
    end

  end
end
