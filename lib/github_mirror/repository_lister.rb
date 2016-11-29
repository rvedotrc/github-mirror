require 'github_api'
require 'json'

module GithubMirror

  class RepositoryLister

    attr_reader :github_client, :json_cache

    def initialize(github_client, json_cache)
      @github_client = github_client
      @json_cache = json_cache
    end

    def each_page
      return enum_for(:each_page) unless block_given?

      if r = json_cache.read
        yield r
      else
        page = github_client.repos.list
        data = []
        loop do
          yield page
          data.concat page.to_a
          page.has_next_page? or break
          page = page.next_page
        end
        json_cache.write data
      end
    end

  end

end
