require 'github_api'
require 'json'

module GithubMirror

  class ListRepositories

    include Enumerable

    attr_reader :auth_file, :cache_file, :max_age

    def initialize
      @auth_file = "etc/github-mirror.json"
      @cache_file = "var/list-repos.json"
      @max_age = 3600

      config = JSON.parse(IO.read auth_file)
      user = config["github"]["user"]
      pass = config["github"]["pass"]

      @github = Github.new basic_auth: user+":"+pass #, auto_pagination: true
    end

    # There's probably a more ruby-esque way of doing this, that supports more
    # kinds of iteration more seamlessly. For now, I'm only supporting the
    # block-style.
    def each
      raise "No block given" unless block_given?

      if list = load_if_fresh
        list.each {|r| yield r}
      else
        list = []
        each_get do |r|
          yield r
          list << r
        end
        save list
      end

      nil
    end

    private

    def each_get
      @github.repos.list.each_page do |page|
        page.each do |r|
          rr = {
            git_url: r.git_url,
            is_private: r.private,
            pushed_at: r.pushed_at,
          }
          yield rr
        end
      end
    end

    def load_if_fresh
      begin
        File.open cache_file do |f|
          age = Time.now - f.stat.mtime
          if age > max_age
            nil
          else
            JSON.parse(f.read, symbolize_names: true)
          end
        end
      rescue Errno::ENOENT
        nil
      end
    end

    def save(data)
      tmp = cache_file + ".tmp"
      IO.write(tmp, JSON.pretty_generate(data)+"\n")
      File.rename tmp, cache_file
    end

  end

end
