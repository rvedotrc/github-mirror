require 'fileutils'
require 'json'
require 'shellwords'
require 'set'

module GithubMirror

  class CloneMissing

    def initialize(options = {})
      @dry_run = !!options[:dry_run]
    end

    def do_clone(url, dir)
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

    def do_fetch(dir)
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

    def write_pushed(pushed_at, dir)
      IO.write("#{dir}/pushed_at", pushed_at)
    end

    def read_pushed(dir)
      begin
        IO.read("#{dir}/pushed_at")
      rescue Errno::ENOENT
        nil
      end
    end

    def write_changed(dir)
      IO.write("#{dir}/mirror-changed", "")
    end

    def run_one(url, pushed_at)
      local_dir = url.gsub("git://github.com/", "var/github/").gsub(/\.git$/, "")

      if Dir.exist? local_dir+"/mirror"
        last_pushed_at = read_pushed local_dir
        if last_pushed_at != pushed_at
          puts "Need to fetch #{url}"
          unless @dry_run
            do_fetch local_dir
            write_pushed pushed_at, local_dir
            write_changed local_dir
          end
        else
          # puts "No change for #{url}"
        end
      else
        puts "Need to clone #{url}"
        unless @dry_run
          do_clone url, local_dir
          write_pushed pushed_at, local_dir
          write_changed local_dir
        end
      end
    end

    def run(data = nil)
      config = JSON.parse(IO.read "etc/github-mirror.json")

      data ||= JSON.parse(IO.read "var/list-repos.json")

      ignored_orgs = Set.new

      data.each do |r|
        url = r["git_url"]
        pushed_at = r["pushed_at"]
        org = url.split('/')[3]

        unless config["github"]["allow_orgs"].nil? or config["github"]["allow_orgs"].include? org
          ignored_orgs << org
          next
        end

        if block_given?
          yield url, pushed_at
        else
          run_one url, pushed_at
        end
      end

      unless ignored_orgs.empty?
        puts "Ignored orgs: #{ignored_orgs.to_a.sort.join " "}"
      end
    end

  end

end