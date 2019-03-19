require 'ostruct'
require 'tempfile'

require 'command_runner'

class GitMergeWithStash
  def self.run(dir)
    status = Tempfile.open do |f|
      system 'git status --porcelain', chdir: dir, out: f.fileno
      f.rewind
      f.read
    end

    requires_stash = status.each_line.any? do |line|
      line[0..1].match /[A-Z]/
    end

    if requires_stash
      # 1 happy outcome
      # 3 "meh" outcomes (at least we ended up in the same state we started in)
      # 4 unhappy outcomes (neither ended in the start state, nor the happy state)

      result = CommandRunner.do_system 'git stash save', chdir: dir
      unless result.success?
        raise MergeWithStashSystemException.new(dir, 'stash save', result, :no_change)
      end

      unless system 'git pull --ff-only', chdir: dir
        system 'git stash pop', chdir: dir \
          or raise "#{dir}: merge failed, and failed to pop the stash. Manual recovery required"
        puts "#{dir}: merge failed, manual merging required"
        return
      end

      if system 'git stash pop', chdir: dir
        puts "#{dir}: stash-merge-pop successful"
        return # :-)
      end

      system "git checkout '@{-1}'", chdir: dir \
        or raise "#{dir}: failed to pop the stash after merging, but then also failed to undo the merge. Manual recovery required"

      if system 'git stash pop', chdir: dir
        puts "#{dir}: stash pop failed, manual merging required"
        return
      else
        raise "#{dir}: failed to pop the stash after merging and rolling back. Manual recovery required"
      end
    else
      system 'git pull --ff-only', chdir: dir \
        or raise "#{dir}: git merge failed"
      puts "#{dir}: merge successful"
      # :-)
    end
  end

  class MergeWithStashSystemException < Exception
    def initialize(dir, command, result, outcome)
      @dir = dir
      @command = command
      @result = result
      @outcome = outcome
    end

    def message
      "#{dir} : #{command} failed, log is: #{outcome.log}"
    end

    def to_s
      message
    end
  end
end

if $0 == __FILE__
  GitMergeWithStash.run(ARGV.first || '.')
end
