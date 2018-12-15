require 'fileutils'
require 'github_mirror/repository_cloner'

class GithubMirror
  class RepositoryProcessor

    def process_repo(repo)
      base_dir = 'var/github'

      id = repo['id']
      full_name = repo['full_name']
      full_name.count('/') == 1 or raise "depth of #{full_name} != 1"

      canonical_dir = "#{base_dir}/id/#{id}"
      symlink_path = "#{base_dir}/full_name/#{full_name}"
      symlink_target = "../../id/#{id}"

      FileUtils.mkdir_p(canonical_dir)

      GithubMirror::RepositoryCloner.new(repo, canonical_dir, full_name).mirror

      begin
        if File.readlink(symlink_path) != symlink_target
          File.unlink symlink_path
          File.symlink symlink_target, symlink_path
        end
      rescue Errno::ENOENT
        FileUtils.mkdir_p(File.dirname symlink_path)
        File.symlink symlink_target, symlink_path
      end
    end

  end
end
