require 'github_api'
require 'json'

module GithubMirror

  class ListRepositories

    def initialize
      config = JSON.parse(IO.read "etc/github-mirror.json")
      user = config["github"]["user"]
      pass = config["github"]["pass"]

      @github = Github.new basic_auth: user+":"+pass #, auto_pagination: true
    end

    def list
      # @github.repos.list.each do |r|
      #   puts "#{r.pushed_at} #{r.git_url}"
      # end

      data = []

      @github.repos.list.each_page do |page|
        page.each do |r|
          $stderr.puts "#{r.pushed_at} #{r.private} #{r.git_url}"
          data << {
            git_url: r.git_url,
            is_private: r.private,
            pushed_at: r.pushed_at,
          }
        end
      end

      data
    end

    def load_if_fresh(max_age)
      begin
        File.open "var/list-repos.json" do |f|
          age = Time.now - f.stat.mtime
          if age > max_age
            nil
          else
            JSON.parse(f.read)
          end
        end
      rescue Errno::ENOENT
        nil
      end
    end

    def save(data)
      file = "var/list-repos.json"
      tmp = file + ".tmp"
      IO.write(tmp, JSON.pretty_generate(data)+"\n")
      File.rename tmp, file
    end

  end

end
