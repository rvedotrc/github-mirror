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

    filtered_repos = repos.select do |repo|
      config['github']['allow_orgs'].include?(repo[:owner_name])
    end

    require 'github_mirror/clone_all'
    GithubMirror::CloneAll.new(filtered_repos, CLONE_BASE_DIR, logger: @logger.nest('clone-all ')).run

    require 'github_mirror/symlink_updater'
    GithubMirror::SymlinkUpdater.new(filtered_repos, CLONE_BASE_DIR, logger: @logger.nest('symlink-updater ')).run

    basenames = filtered_repos.map do |repo|
      dir = "#{CLONE_BASE_DIR}/full_name/#{repo.full_name}"
      Dir.entries(dir).sort - [".", ".."]
    end

    p basenames.group_by(&:itself).to_h.transform_values(&:count)
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

  def repo_enum
    ttl = config['repositories_list_ttl'].to_i

    require 'github_mirror/cacheing_thing'
    GithubMirror::CacheingThing.new(REPOSITORIES_FILE, Time.now - ttl, logger: @logger.nest("repositories-cache ")) do
      require 'github_mirror/github_paginating_enumerator'
      github_client.repos.list.lazy_each(logger: @logger.nest('repositories-enum '))
    end
  end

  def repos
    # Reads the entire repo list before returning it. Favours code simplicity over concurrency.

    @repos ||= begin
                 all = []
                 repo_enum.each { |r| all << r } # Ugh

                 all.map do |repo|
                   RepoSummary.new.tap do |s|
                     s.id = repo["id"]
                     s.full_name = repo["full_name"]
                     s.owner_name = repo["owner"]["login"]
                     s.ssh_url = repo["ssh_url"]
                     s.pushed_at = repo["pushed_at"]
                     s.default_branch = repo["default_branch"]
                   end
                 end
               end
  end

end
