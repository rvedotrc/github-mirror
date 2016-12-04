require 'fileutils'
require 'json'
require 'shellwords'
require 'set'

module GithubMirror

  class RepositoryCloner

    attr_reader :dir, :dry_run

    def initialize(dir, dry_run)
      @dir = dir
      @dry_run = dry_run
    end

    private

    def do_clone(url)
      FileUtils.mkdir_p dir

      mirror_dir = "#{dir}/mirror"
      mirror_tmp = "#{dir}/mirror.tmp"
      legacy_dir = "#{dir}/repository"

      FileUtils.rm_rf mirror_dir
      FileUtils.rm_rf mirror_tmp

      # So we can access private repositories
      url = url.sub "git:", "ssh:"

      puts "git clone --mirror #{url} #{mirror_tmp}"
      system "git", "clone", "--mirror", url, mirror_tmp
      $?.success? or raise "git clone failed"

      File.rename mirror_tmp, mirror_dir
    end

    def do_fetch
      puts "git fetch"
      system "with-cwd", "#{dir}/mirror", "git", "fetch"
      unless $?.success?
        # This can happen when local (or remote) has a ref like "foo/bar", but
        # remote (or local) has a ref like "foo".  Because of the way that git
        # stores refs in the filesystem, it then has trouble switching "foo" from
        # directory to a file, or vice versa.
        puts "Trying git remote prune origin"
        system "with-cwd", "#{dir}/mirror", "git", "remote", "prune", "origin"
        puts "git fetch (again)"
        system "with-cwd", "#{dir}/mirror", "git", "fetch"
      end
      $?.success? or raise "git fetch failed"
    end

    def write_pushed(pushed_at)
      IO.write("#{dir}/pushed_at", pushed_at)
    end

    def read_pushed
      begin
        IO.read("#{dir}/pushed_at")
      rescue Errno::ENOENT
        nil
      end
    end

    public

    def run(url, pushed_at)
      if Dir.exist? dir+"/mirror"
        last_pushed_at = read_pushed
        if last_pushed_at != pushed_at
          puts "Need to fetch #{url}"
          unless @dry_run
            do_fetch
            write_pushed pushed_at
          end
        else
          # puts "No change for #{url}"
        end
      else
        puts "Need to clone #{url}"
        unless @dry_run
          do_clone url
          write_pushed pushed_at
        end
      end
    end

  end

end
