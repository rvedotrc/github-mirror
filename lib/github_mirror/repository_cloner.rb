require 'fileutils'
require 'tempfile'

class GithubMirror
  class RepositoryCloner

    attr_reader :ssh_url, :pushed_at, :canonical_dir, :full_name

    def initialize(ssh_url, pushed_at, canonical_dir, full_name)
      @ssh_url = ssh_url
      @pushed_at = pushed_at
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

    def target
      "#{canonical_dir}/mirror"
    end

    def clone
      puts "clone #{full_name} into #{canonical_dir}"

      FileUtils.mkdir_p canonical_dir
      tmp = target + ".tmp"
      FileUtils.rm_rf(target)
      FileUtils.rm_rf(tmp)

      system "git", "clone",
        "--bare",
        "--config", 'remote.origin.fetch=+refs/*:refs/origin/*',
        ssh_url, tmp
      $?.success? or raise "git clone #{full_name} failed"

      File.rename tmp, target

      with_pushed_at { }
    end

    def fetch
      updated = with_pushed_at do
        puts "git fetch #{full_name} => #{canonical_dir}"
        do_fetch
      end

      updated or puts "fetch #{full_name} (nothing to do)"
    end

    def do_fetch
      Tempfile.open do |t|
        Process.wait(Process.spawn(
          "git", "--git-dir", target, "fetch", "--prune",
          out: t,
          err: t,
        ))
        t.rewind

        puts(*t.each_line.map {|t| "#{full_name} : #{t}"})
        next if $?.success?

        t.rewind
        log = t.read

        if log.match(/\Afatal: Couldn't find remote ref HEAD\n*\z/)
          puts "#{full_name} is an empty repository"
          next
        end

        raise "git fetch #{full_name} failed: #{log}"
      end
    end

    def with_pushed_at
      pushed_at_file = "#{canonical_dir}/pushed_at"

      already_done = begin
                       IO.read(pushed_at_file).chomp
                     rescue Errno::ENOENT
                     end

      if already_done == pushed_at
        return false
      end

      yield

      IO.write(pushed_at_file, pushed_at+"\n")
      true
    end

  end
end
