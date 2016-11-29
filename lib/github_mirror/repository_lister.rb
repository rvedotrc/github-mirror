require 'github_api'
require 'json'

module GithubMirror

  class RepositoryLister

    attr_reader :github_client, :json_cache

    def initialize(github_client, json_cache)
      @github_client = github_client
      @json_cache = json_cache
    end

    def each_page(&block)
      return enum_for(:each_page) unless block_given?

      if r = json_cache.read
        yield r
      else
        each_page_uncached block
      end
    end

    def each_page_uncached(block)
      page = github_client.repos.list
      data = []

      loop do
        hashes = page.map do |r|
          {
            "git_url" => r.git_url,
            "is_private" => r.private,
            "pushed_at" => r.pushed_at,
          }
        end

        block.call hashes
        data.concat hashes.to_a

        page.has_next_page? or break
        page = page.next_page
      end

      json_cache.write data
    end

  end

end
