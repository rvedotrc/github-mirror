class GithubMirror
  class RepositoryProcessor

    attr_reader :repo, :full_name, :canonical_dir, :symlink_path, :symlink_target

    def initialize(base_dir, repo)
      @base_dir = base_dir
      @repo = repo

      @full_name = repo.full_name
      @full_name.count('/') == 1 or raise "depth of #{full_name} != 1"

      @canonical_dir = File.join(base_dir, 'id', repo.id.to_s)
    end

    def process
      require 'fileutils'
      FileUtils.mkdir_p(canonical_dir)

      require 'github_mirror/repo_meta'
      meta = GithubMirror::RepoMeta.new(canonical_dir)
      meta.set(:github_info, :full_name, full_name)

      require 'github_mirror/repository_cloner'
      RepositoryCloner.new(repo.ssh_url, repo.pushed_at, canonical_dir, full_name, meta).mirror
      require 'github_mirror/checkout_maker'
      CheckoutMaker.new(repo.ssh_url, canonical_dir, meta, repo.default_branch).mirror

      require 'github_mirror/tree_maker'
      TreeMaker.new(canonical_dir, meta, repo.default_branch).update

      meta.flush
    end

  end
end
