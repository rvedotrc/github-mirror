require 'github_api'

# Patch a github api response to add lazy_each
class Github::ResponseWrapper
  def lazy_each(logger:, &block)
    e = GithubMirror::GithubPaginatingEnumerator.new(self, logger: logger)
    if block_given?
      e.each(&block)
    else
      e
    end
  end
end

# Implementation of lazy_each. An iterator which yields each item
# in the page, and automatically fetches the next page, until done.
class GithubMirror
  class GithubPaginatingEnumerator

    include Enumerable

    def initialize(first_page, logger:)
      @page = first_page
      @page_number = 0
      @index = 0
      @logger = logger
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
          return v
        end

        unless @page.has_next_page?
          break
        end

        @page = @page.next_page
        @page_number += 1
        @index = 0
        @logger.puts "Now on page #{@page_number}"
      end

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
end
