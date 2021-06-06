class GithubMirror
  class TreeMaker

    TREE_FILE = 'tree.json'

    def initialize(canonical_dir, meta, default_branch)
      @canonical_dir = canonical_dir
      @meta = meta
      @default_branch = default_branch
    end

    attr_reader :canonical_dir, :meta, :default_branch

    def update
      last_fetched_at = meta.get(:mirror, :last_fetched_at)
      return if last_fetched_at.nil?
      return if last_fetched_at == meta.get(:tree, :last_updated_at)

      git_dir = "#{canonical_dir}/#{MIRROR_DIR}"

      require 'github_mirror/git_command_runner'
      answer = GitCommandRunner.run("git", "--git-dir", git_dir, "show-ref", "refs/heads/#{default_branch}")

      return if answer[:status].exitstatus == 1

      refs = answer[:out].lines.map(&:chomp).select { |t| t.end_with?(" refs/heads/#{default_branch}") }
      refs.count == 1 or raise "Expected 1 ref, got #{refs.inspect}"

      commit = refs.first.split(' ')[0]

      binary_tree = GitCommandRunner.run!("git", "--git-dir", git_dir, "ls-tree", "-z", "-r", "-l", "-t", commit)[:out]

      tree = binary_tree.each_line("\0").map do |l|
        l.chomp!("\0")
        # TODO: symlinks, I bet
        details, path = l.split /\t/, 2
        mode, type, hash, size = details.split ' '
        size = if size != '-' ; size.to_i ; end
        { mode: mode, type: type, hash: hash, size: size, path: path }
      end

      tree_file = "#{canonical_dir}/#{TREE_FILE}"
      puts "Saving #{tree.count} tree entries to #{tree_file}"

      require 'json'
      require 'tempfile'

      Tempfile.open(tree_file) do |f|
        f.puts(JSON.generate(tree))
        f.flush
        f.chmod 0o644
        File.rename f.path, tree_file
      end

      meta.set(:tree, :commit, commit)
      meta.set(:tree, :last_updated_at, last_fetched_at)
    end

  end
end
