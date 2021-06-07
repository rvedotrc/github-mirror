class GithubMirror
  class CloneAll

    def initialize(repos, clone_base_dir, logger:)
      @repos = repos
      @clone_base_dir = clone_base_dir
      @logger = logger
    end

    attr_reader :repos, :clone_base_dir

    def run
      require 'github_mirror/repository_processor'

      repos.each do |repo|
        logger = @logger.nest(repo.full_name + ' ')
        GithubMirror::RepositoryProcessor.new(clone_base_dir, repo, logger: logger).process
      end
    end

  end
end
