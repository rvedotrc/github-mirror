require 'shellwords'

module GithubMirror

  class GitRefReader

    def self.read_git_refs(git_dir)
      # Could / should use git for-each-ref --format "..."
      lines = `cd #{Shellwords.shellescape git_dir} && git for-each-ref`.lines
      lines.reduce({}) do |h, l|
        m = l.match /^(?<commit>\w{40}) (?<type>\S+)\s+(?<ref>.*)$/
        m or raise "Failed to parse for-each-ref line #{l.inspect} in #{git_dir.inspect}"

        entry = {
          "commit" => m["commit"],
          "type" => m["type"],
          "ref" => m["ref"],
        }

        h[ entry["ref"] ] = entry
        h
      end
    end

  end

end
