require 'fileutils'
require 'github_mirror/repository_cloner'
# require 'github_mirror/secret_material_scanner'

class GithubMirror
  class RepositoryProcessor

    attr_reader :repo, :full_name, :canonical_dir, :symlink_path, :symlink_target

    def initialize(base_dir, repo)
      @base_dir = base_dir
      @repo = repo

      @full_name = repo['full_name']
      @full_name.count('/') == 1 or raise "depth of #{full_name} != 1"

      @canonical_dir = File.join(base_dir, 'id', repo['id'].to_s)
      @symlink_path = File.join(base_dir, 'full_name', repo['full_name'])
      @symlink_target = File.join('../../id', repo['id'].to_s)
    end

    def process
      FileUtils.mkdir_p(canonical_dir)
      RepositoryCloner.new(repo['ssh_url'], repo['pushed_at'], canonical_dir, full_name).mirror
      update_symlink

#       [
#         AWSAccessKeyScanner,
#         # PrivateKeyScanner,
#       ].each do |c|
#         c.new(
#           canonical_dir,
#           canonical_dir + "/mirror",
#           full_name,
#           repo['pushed_at'],
#         ).run
#       end
    end

    def update_symlink
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
