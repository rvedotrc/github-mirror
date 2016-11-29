require 'github_api'
require 'json'

module GithubMirror

  class GithubClient

    def self.get(auth_file)
      config = JSON.parse(IO.read auth_file)
      user = config["github"]["user"]
      pass = config["github"]["pass"]

      Github.new basic_auth: user+":"+pass #, auto_pagination: true
    end

  end

end
