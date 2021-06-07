class GithubMirror

  CONFIG_FILE = 'etc/github-mirror.json'
  REPOSITORIES_FILE = 'var/repositories.json'
  CLONE_BASE_DIR = 'var/github'
  MIRROR_DIR = "mirror"
  CHECKOUT_DIR = "checkout"

  RepoSummary = Struct.new(:id, :full_name, :owner_name, :ssh_url, :pushed_at, :default_branch)

  def run
    require 'github_mirror/prefixed_logger'
    @logger = GithubMirror::PrefixedLogger.new

    require 'github_mirror/clone_all'
    cloner = GithubMirror::CloneAll.new(CLONE_BASE_DIR, logger: @logger.nest('clone-all '))

    repos = []
    promises = []

    each_repo_summary do |repo|
      repos << repo
      promises << cloner.run(repo)
    end

    Rosarium::Promise.all(promises).value!

    require 'github_mirror/symlink_updater'
    GithubMirror::SymlinkUpdater.new(repos, CLONE_BASE_DIR, logger: @logger.nest('symlink-updater ')).run

    basenames = repos.map do |repo|
      dir = "#{CLONE_BASE_DIR}/full_name/#{repo.full_name}"
      Dir.entries(dir).sort - [".", ".."]
    end

    p basenames.group_by(&:itself).to_h.transform_values(&:count)

    Rosarium::EXECUTOR.wait_until_idle
  end

  private

  def config
    require 'json'
    @config ||= JSON.parse(IO.read(CONFIG_FILE))
  end

  def github_client
    user = config['github']['user']
    pass = config['github']['pass']

    require 'github_api'
    @github_client ||= Github.new(
      basic_auth: user+':'+pass,
      auto_pagination: false,
    )
  end

  def github_repo_enum
    ttl = config['repositories_list_ttl'].to_i

    require 'github_mirror/cacheing_thing'
    GithubMirror::CacheingThing.new(REPOSITORIES_FILE, Time.now - ttl, logger: @logger.nest("repositories-cache ")) do
      require 'github_mirror/github_paginating_enumerator'
      github_client.repos.list.lazy_each(logger: @logger.nest('repositories-enum '))
    end
  end

  def each_repo_summary(*args)
    return enum_for(:each_repo_summary, *args) unless block_given?

    github_repo_enum.each do |github_repo|
      repo_summary = RepoSummary.new.tap do |s|
        s.id = github_repo["id"]
        s.full_name = github_repo["full_name"]
        s.owner_name = github_repo["owner"]["login"]
        s.ssh_url = github_repo["ssh_url"]
        s.pushed_at = github_repo["pushed_at"]
        s.default_branch = github_repo["default_branch"]
      end

      next unless config['github']['allow_orgs'].include?(repo_summary.owner_name)

      yield repo_summary
    end
  end

end
