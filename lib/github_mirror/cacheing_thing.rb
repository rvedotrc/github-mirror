require 'json'

# Apply filesystem cacheing to the results of an enumerator.
# If the cache is fresh, thing.each iterates over each cached
# result (as serialized/deserialized using JSON). Otherwise,
# calls the underlying enumerator, generating a new set of
# cached results, renaming it into place on completion.

class GithubMirror
  class CacheingThing
    def initialize(filename, cutoff_time, logger:, &block)
      @filename = filename
      @cutoff_time = cutoff_time
      @block = block
      @logger = logger
    end

    def each
      raise unless block_given?

      require 'json'

      return if with_fresh_file do |f|
        JSON.load(f).each do |v|
          yield v
        end
      end

      tmp = @filename + ".tmp"
      File.open(tmp, 'w') do |f|
        f.print '['
        e = @block.call
        i = 0
        e.each do |v|
          f.print ',' unless i == 0
          i += 1
          JSON.dump(v, f)
          yield v.to_h
        end
        f.print "]\n"
      end
      File.rename tmp, @filename

      nil
    end

    private

    # If the file exists and is fresh, then yields the filehandle and returns true.
    # otherwise returns false.
    def with_fresh_file
      f = begin
        File.open(@filename, 'r')
      rescue Errno::ENOENT
        nil
      end

      begin
        if f and f.stat.mtime > @cutoff_time
          @logger.puts "Using fresh (#{(f.stat.mtime - @cutoff_time).to_i} sec old) file"
          yield f
          true
        else
          @logger.puts "Querying repositories"
          false
        end
      ensure
        f.close if f
      end
    end

  end
end
