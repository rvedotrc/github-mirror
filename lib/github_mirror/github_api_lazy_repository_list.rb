class GithubMirror
  class GithubAPILazyRepositoryList

    def initialize(github_client, logger:)
      @github_client = github_client
      @logger = logger
    end

    def each(&block)
      @logger.puts "Fetching Github API repos list"
      first_page = @github_client.repos.list
      require_relative './github_paginating_enumerator'
      enum = GithubMirror::GithubPaginatingEnumerator.new(first_page, logger: @logger.nest("#{self.class} "))
      enum.each(&block)
    end

  end
end
