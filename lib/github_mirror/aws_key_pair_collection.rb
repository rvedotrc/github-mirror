require 'time'

module GithubMirror

  class AwsKeyPairCollection

    def initialize(filename)
      @json_cache = JsonCache.new(filename, nil)
    end

    def load
      if file_data = @json_cache.read
        file_data["by_access_key"].entries.map do |ak, key_data|
          [ ak, AwsKeyPair.from_h(key_data) ]
        end.to_h
      else
        {}
      end
    end

    def save(h)
      file_data = h.entries.map do |ak, key_pair|
        [ ak, key_pair.to_h ]
      end.to_h
      file_data = { "by_access_key" => file_data }

      @json_cache.write file_data
    end

  end

end
