class GithubMirror
  class TreeMaker

    TREE_FILE = 'tree.json'

    def initialize(canonical_dir, meta, default_branch, logger:)
      @canonical_dir = canonical_dir
      @meta = meta
      @default_branch = default_branch
      @logger = logger

      require 'github_mirror/git_command_runner'
      @gcr = GitCommandRunner.new(logger: @logger)
    end

    attr_reader :canonical_dir, :meta, :default_branch, :gcr

    def update
      last_fetched_at = meta.get(:mirror, :last_fetched_at)
      return if last_fetched_at.nil?
      return if last_fetched_at == meta.get(:tree, :last_updated_at)

      mirror_dir = "#{canonical_dir}/#{MIRROR_DIR}"

      answer = gcr.run(
        "git", "show-ref", "--verify", "refs/origin/heads/#{default_branch}",
        chdir: mirror_dir,
        catch: -> (r) do
          if r[:status].exitstatus == 128 && r[:err].include?("not a valid ref")
            r[:not_a_valid_ref] = true
            r[:status] = Struct.new(:success?).new(true)
          end

          r
        end,
      )

      return if answer[:not_a_valid_ref]

      commit = answer[:out].split(' ')[0]

      binary_tree = gcr.run(
        "git", "ls-tree", "-z", "-r", "-l", "-t", commit,
        chdir: mirror_dir,
      )[:out]

      tree = binary_tree.each_line("\0").map do |l|
        l.chomp!("\0")
        # TODO: symlinks, I bet
        details, path = l.split /\t/, 2
        mode, type, hash, size = details.split ' '
        size = if size != '-' ; size.to_i ; end
        { mode: mode, type: type, hash: hash, size: size, path: path }
      end

      tree_file = "#{canonical_dir}/#{TREE_FILE}"
      @logger.puts "Saving #{tree.count} tree entries to #{tree_file}"

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
