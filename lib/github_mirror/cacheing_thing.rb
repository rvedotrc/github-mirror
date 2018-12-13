require 'json'

class CacheingThing
  def initialize(filename, cutoff_time, &block)
    @filename = filename
    @cutoff_time = cutoff_time
    @block = block
  end

  def each
    raise unless block_given?

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

  def with_fresh_file
    f = begin
      File.open(@filename, 'r')
    rescue Errno::ENOENT
      nil
    end

    f or return

    begin
      if f.stat.mtime > @cutoff_time
        yield f
      end
    ensure
      f.close
    end

    true
  end

end
