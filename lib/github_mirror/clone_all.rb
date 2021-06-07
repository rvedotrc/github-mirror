class GithubMirror
  class CloneAll

    def initialize(repos, clone_base_dir, logger:)
      @repos = repos
      @clone_base_dir = clone_base_dir
      @logger = logger
    end

    attr_reader :repos, :clone_base_dir

    def run
      require 'rosarium/promise_concurrency_limiter'
      limiter = Rosarium::PromiseConcurrencyLimiter.new(3)

      require 'github_mirror/repository_processor'
      Rosarium::Promise.all(
        repos.map do |repo|
          limiter.promise do
            Rosarium::Promise.execute do
              logger = @logger.nest(repo.full_name + ' ')
              GithubMirror::RepositoryProcessor.new(clone_base_dir, repo, logger: logger).process
            end
          end
        end
      ).value!
    end

  end
end
