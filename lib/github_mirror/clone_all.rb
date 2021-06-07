class GithubMirror
  class CloneAll

    def initialize(clone_base_dir, logger:)
      @clone_base_dir = clone_base_dir
      @logger = logger

      require 'rosarium/promise_concurrency_limiter'
      @limiter = Rosarium::PromiseConcurrencyLimiter.new(3)
    end

    attr_reader :limiter, :clone_base_dir

    def run(repo)
      require 'github_mirror/repository_processor'
      limiter.promise do
        Rosarium::Promise.execute do
          logger = @logger.nest(repo.full_name + ' ')
          GithubMirror::RepositoryProcessor.new(clone_base_dir, repo, logger: logger).process
        end
      end
    end

  end
end
