require 'find'

class GithubMirror
  class SymlinkUpdater

    def initialize(repos, clone_base_dir, logger:)
      @repos = repos
      @clone_base_dir = clone_base_dir
      @logger = logger
    end

    attr_reader :repos, :clone_base_dir

    def run
      desired_symlinks = repos.map do |repo|
        [ "#{clone_base_dir}/full_name/#{repo.full_name}", "../../id/#{repo.id}" ]
      end.to_h


      base_slash_count = clone_base_dir.count('/')
      existing_symlinks = Find.find("#{clone_base_dir}/full_name").select { |path| path.count('/') == base_slash_count + 3 }.map do |path|
        target = File.readlink(path)
        [ path, target ]
      end.to_h

      (desired_symlinks.keys - existing_symlinks.keys).each do |k|
        @logger.puts "ln -s #{k} #{desired_symlinks[k]}"
        File.symlink desired_symlinks[k], k
      end

      (existing_symlinks.keys - desired_symlinks.keys).each do |k|
        @logger.puts "rm #{k}"
        File.unlink k
      end

      (desired_symlinks.keys & existing_symlinks.keys).each do |k|
        if desired_symlinks[k] != existing_symlinks[k]
          @logger.puts "ln -sf #{k} #{desired_symlinks[k]}"
          File.unlink k
          File.symlink desired_symlinks[k], k
        end
      end
    end

  end
end
