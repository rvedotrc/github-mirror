module GithubMirror

  class CollectingIterator

    include Enumerable

    def self.run
      iter = [4,5,6,7].each

      wrapped = CollectingIterator.new(iter) do |list|
        puts "list=#{list}"
      end

      p wrapped.to_a

      p wrapped.next
      p wrapped.next
      p wrapped.next
      p wrapped.next
      p wrapped.next
      p wrapped.next
    end

    def initialize(iter, &block)
      @iter = iter
      @block = block
      @list = []
    end

    def each
      self
    end

    def next
      begin
        ans = @iter.next
        @list << ans
        ans
      rescue StopIteration => e
        @block.call @list
        @list = []
        raise
      end
    end

  end

end

GithubMirror::CollectingIterator.run
