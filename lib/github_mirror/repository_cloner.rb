require 'fileutils'
require 'tempfile'

class GithubMirror
  class RepositoryCloner

    attr_reader :repo, :canonical_dir, :full_name

    def initialize(repo, canonical_dir, full_name)
      @repo = repo
      @canonical_dir = canonical_dir
      @full_name = full_name
    end

    def mirror
      if Dir.exists?(canonical_dir)
        fetch
      else
        clone
      end
    end

    private

    def clone
      puts "clone #{repo['full_name']} into #{canonical_dir}"

      FileUtils.mkdir_p canonical_dir
      target = "#{canonical_dir}/mirror"
      tmp = "#{canonical_dir}/mirror.tmp"

      FileUtils.rm_rf(tmp)
      system "git", "clone", "--bare", repo['ssh_url'], tmp
      $?.success? or raise "git clone #{repo['full_name']} failed"

      File.rename tmp, target
    end

    def fetch
      pushed_at = "#{canonical_dir}/pushed_at"

      already_done = begin
                       IO.read(pushed_at).chomp
                     rescue Errno::ENOENT
                     end

      if repo['pushed_at'] == already_done
        puts "fetch #{repo['full_name']} (nothing to do)"
        return
      end

      puts "git fetch #{repo['full_name']} => #{canonical_dir}"
      do_fetch canonical_dir + "/mirror"
      IO.write(pushed_at, repo['pushed_at']+"\n")
    end

    def do_fetch(git_dir)
      Tempfile.open do |t|
        Process.wait(Process.spawn(
          "git", "--git-dir", git_dir, "fetch", "--prune",
          out: t,
          err: t,
        ))
        t.rewind

        puts(*t.each_line.map {|t| "#{git_dir} : #{t}"})
        next if $?.success?

        t.rewind
        log = t.read

        if log.match(/\Afatal: Couldn't find remote ref HEAD\n*\z/)
          puts "#{full_name} is an empty repository"
          next
        end

        raise "git fetch #{git_dir} (#{full_name}) failed: #{log}"
      end
    end

  end
end
