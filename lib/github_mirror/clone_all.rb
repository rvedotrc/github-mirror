class GithubMirror
  class CloneAll

    def initialize(repos, clone_base_dir)
      @repos = repos
      @clone_base_dir = clone_base_dir
    end

    attr_reader :repos, :clone_base_dir

    def run
      require 'github_mirror/repository_processor'

      repos.each do |repo|
        puts repo.full_name
        GithubMirror::RepositoryProcessor.new(clone_base_dir, repo).process
      end
    end

  end
end
