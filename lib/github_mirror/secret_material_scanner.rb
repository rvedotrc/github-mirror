require 'github_mirror/git_command_runner'

class GithubMirror
  class SecretMaterialScanner

    attr_reader :canonical_dir, :git_dir, :full_name, :pushed_at

    def initialize(canonical_dir, git_dir, full_name, pushed_at)
      @canonical_dir = canonical_dir
      @git_dir = git_dir
      @full_name = full_name
      @pushed_at = pushed_at
    end

    def run
      state = load_state
      return if state['pushed_at'] == pushed_at
      puts "Scanning #{full_name}"

      state['log'] ||= []
      old_heads = state['heads'] || []
      new_heads = read_heads

      to_process = new_heads - old_heads

      until to_process.empty?
        pick = if to_process.count > 1 and commit_count(to_process, old_heads) > 5000
                 new_heads.first
               else
                 new_heads
               end
        new_heads -= pick

        new_log = read_new_commits(pick, old_heads)
        puts "#{full_name} scanned pick=#{pick.count} new_heads=#{new_heads.count} old_heads=#{old_heads.count} logs=#{new_log.count}"

        state['log'].concat new_log
        state['pushed_at'] = pushed_at if new_heads.empty?
        state['heads'] = new_heads.sort

        set 'pushed_at' if that was the end
        save state
      end



      save_state state
    end

    private

    def load_state
      JSON.parse(IO.read state_file)
    rescue Errno::ENOENT
      {}
    end

    def save_state(state)
      tmp = state_file + ".tmp"
      IO.write(tmp, JSON.generate(state)+"\n")
      File.rename tmp, state_file
    end

    def read_heads
      r = GitCommandRunner.run!(
        'git', 'for-each-ref',
        chdir: git_dir,
      )

      r[:out].each_line.map do |l|
        l.split(' ').first
      end.sort.uniq
    end

    def read_new_commits(new_heads, old_heads)
      new_only = new_heads - old_heads
      return [] if new_only.empty?

      rev_list = begin
        GitCommandRunner.run!(
          'git', 'rev-list',
          *new_only.sort,
          *old_heads.sort.map {|rev| "^"+rev},
          chdir: git_dir,
        )
      end

      commit_count = rev_list[:out].each_line.count

      raise "lol no #{commit_count} / #{new_only.count} / #{old_heads.count}" if commit_count > 10000

      r = GitCommandRunner.run!(
        'git', 'log',
          '--reverse',
          '--date=iso-strict',
          '-U10',
          '--cc',
          *git_log_arguments,
          *new_only.sort,
          *old_heads.sort.map {|rev| "^"+rev},
        chdir: git_dir,
      )

      # Discard the "" right at the start of the string
      # Discard any merge commits (which are included in spite of -G)
      r[:out].split(/^commit /).select {|t| filter t}
    end

  end

  class AWSAccessKeyScanner < SecretMaterialScanner
    def git_log_arguments
      ['-GAKIA']
    end

    def filter(t)
      t.match /\bAKIA/
    end

    def state_file
      "#{canonical_dir}/AWSAccessKeyScanner.json"
    end
  end

end
