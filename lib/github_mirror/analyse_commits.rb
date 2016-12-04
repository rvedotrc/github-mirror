require 'time'

module GithubMirror

  class AnalyseCommits

    def interesting?(lines)
      lines.any? {|l| l.match /AKIA/}
    end

    def extract_secrets(text)
      text = text.join ""

      # Public keys: 20 chars, A-Z0-9, starting with "AKIA"
      # Secret keys: 40 chars, A-Za-z0-9+/, but allow for \ or \\ before the
      # non-alphanumeric chars

      public_access_keys = text.scan /\bAKIA[A-Z0-9]{16}\b/
      secret_access_keys = text.scan /(?:[A-Za-z0-9]|\\*[\/+]){40,}/
      secret_access_keys = secret_access_keys.map {|t| t.gsub /\\/, ""}
      secret_access_keys = secret_access_keys.select {|t| t.length == 40}

      public_access_keys.sort!
      secret_access_keys.sort!
      {
        public_access_keys: public_access_keys,
        secret_access_keys: secret_access_keys,
      }
    end

    def permute_key_pairs(secrets)
      secrets[:public_access_keys].map do |p|
        secrets[:secret_access_keys].map do |s|
          [ p, s ]
        end
      end.flatten(1)
    end

    def parse_local_dir(local_dir)
      r = {
        local_dir: local_dir,
      }

      if m = local_dir.match(/^var\/github\/(.*?)\/(.*)$/)
        r[:github] = {
          organisation: m[1],
          repository: m[2],
        }
      end

      r
    end

    def parse_commit(lines)
      c = {
        lines: lines,
      }

      lines.each_with_index do |l, i|
        if m = l.match(/^commit (\w{40})$/)
          c[:commit] = m[1]
        elsif m = l.match(/^Author:\s*(.*)$/)
          c[:author] = m[1]
        elsif m = l.match(/^Date:\s*(.*)$/)
          t = Time.parse(m[1]).utc
          c[:time] = {
            epoch: t.to_i,
            iso: t.strftime('%Y-%m-%dT%H:%M:%SZ'),
          }
        elsif l == "\n"
          c[:message] = lines[i+1 .. -2]
        end
      end

      c
    end

    def parse_file(lines)
      f = {
        lines: lines,
      }

      lines.each do |l|
        if m = l.match(/^(--- a|\+\+\+ b)\/(.*)$/)
          f[:filename] = m[2]
        end
      end

      f
    end

    def analyse(commit, file, hunk)
      old_text = hunk.select {|l| l.match /^[ -]/}.map {|l| l[1..-1]}
      new_text = hunk.select {|l| l.match /^[ +]/}.map {|l| l[1..-1]}

      old_secrets = extract_secrets old_text
      new_secrets = extract_secrets new_text

      return if old_secrets == new_secrets

      old_permutations = permute_key_pairs(old_secrets)
      new_permutations = permute_key_pairs(new_secrets)

      return if old_permutations.empty? and new_permutations.empty?

      {
        "commit" => parse_commit(commit),
        "file" => parse_file(file),
        # "hunk" => hunk,
        "old_secrets" => old_secrets,
        "new_secrets" => new_secrets,
        "old_permutations" => old_permutations,
        "new_permutations" => new_permutations,
      }
    end

  end

end
