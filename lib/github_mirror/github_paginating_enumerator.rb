require 'github_api'

class Github::ResponseWrapper
  def lazy_each(&block)
    e = GithubPaginatingEnumerator.new(self)
    if block_given?
      e.each(&block)
    else
      e
    end
  end
end

class GithubPaginatingEnumerator

  include Enumerable

  def initialize(first_page)
    @page = first_page
    @page_number = 0
    @index = 0
  end
  
  def each
    return self unless block_given?

    stopped = false
    while true
      r = begin
        self.next
      rescue StopIteration
        stopped = true
      end

      break if stopped
      yield r
    end
  end

  def next
    raise if block_given?
    # puts "#{inspect}#next called"

    loop do
      if @index < @page.count
        v = @page[@index]
        @index += 1
        # puts "Returning #{v.class}"
        return v
      end

      unless @page.has_next_page?
        break
      end

      @page = @page.next_page
      @page_number += 1
      @index = 0
      puts "Now self=#{inspect}"
    end

    # puts "raising StopIteration"
    raise StopIteration.new
  end

  def inspect
    "#<#{self.class}:0x%016x %d/%d %d %s>" % [
      object_id,
      @index,
      @page.count,
      @page_number,
      @page.has_next_page?,
    ]
  end
end
