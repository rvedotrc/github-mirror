require 'fileutils'
require 'github_mirror/repository_cloner'

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
      FileUtils.mkdir_p(canonical_dir)

      require 'github_mirror/repo_meta'
      meta = GithubMirror::RepoMeta.new(canonical_dir)

      RepositoryCloner.new(repo.ssh_url, repo.pushed_at, canonical_dir, full_name, meta).mirror

      meta.set(:last_fetched_at, repo.pushed_at)

      meta.flush
    end

  end
end
