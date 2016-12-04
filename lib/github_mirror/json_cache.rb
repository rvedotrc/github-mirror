module GithubMirror

  class JSONCache

    attr_reader :filename, :max_age

    def initialize(filename, max_age)
      @filename = filename
      @max_age = max_age
    end

    def read
      begin
        File.open(filename) do |f|
          if max_age.nil? or f.mtime >= Time.now - max_age
            JSON.parse(f.read)
          end
        end
      rescue Errno::ENOENT
      end
    end

    def write(data)
      body = JSON.generate(data) + "\n"
      tmp_file = filename + ".tmp"
      IO.write tmp_file, body
      File.rename tmp_file, filename
    end

  end

  JsonCache = JSONCache

end
