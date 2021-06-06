require 'fileutils'
require 'tempfile'

class GithubMirror
  class RepositoryCloner

    attr_reader :ssh_url, :pushed_at, :canonical_dir, :full_name, :meta

    def initialize(ssh_url, pushed_at, canonical_dir, full_name, meta)
      @ssh_url = ssh_url
      @pushed_at = pushed_at
      @canonical_dir = canonical_dir
      @full_name = full_name
      @meta = meta
    end

    def mirror
      if Dir.exists?(target)
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
      puts "clone #{full_name} into #{target}"

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

      meta.set(:mirror, :last_fetched_at, pushed_at)
    end

    def fetch
      return if meta.get(:mirror, :last_fetched_at) == pushed_at

      puts "git fetch #{full_name} => #{canonical_dir}"
      do_fetch

      meta.set(:mirror, :last_fetched_at, pushed_at)
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

  end
end
