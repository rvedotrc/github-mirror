require 'json'

class GithubMirror
  class RepoMeta

    def initialize(id_dir)
      @id_dir = id_dir
      load
    end

    def get(*path)
      path.reduce(data) do |h, k|
        h[k.to_s]
      end
    end

    def set(*path_and_value)
      path = path_and_value
      value = path.pop
      final = path.pop

      hash = path.reduce(data) do |h, k|
        h[k.to_s] ||= {}
      end

      hash[final.to_s] = value
      @dirty = true
    end

    def flush
      save if @dirty
    end

    private

    attr_reader :id_dir, :data

    def meta_path
      "#{id_dir}/meta.json"
    end

    def load
      @data = JSON.parse(IO.read(meta_path))
      @dirty = false
    rescue Errno::ENOENT
      @dirty = true
      {}
    end

    def save
      Tempfile.open(meta_path) do |f|
        f.puts(JSON.generate(data))
        f.flush
        f.chmod 0o644
        File.rename f.path, meta_path
      end

      @dirty = false
    end

  end
end
