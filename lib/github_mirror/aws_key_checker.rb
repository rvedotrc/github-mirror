require 'aws-sdk'

module GithubMirror

  class AwsKeyChecker

    def run(collection, fast_run_data, sts_config)
      key_pairs = collection.load
      recheck_secret_found key_pairs, sts_config
      check_new_secrets key_pairs, fast_run_data, sts_config
      collection.save key_pairs
    end

    # Existing key pairs that are :secret_found, re-validate
    # and do either add_secret_found or add_bad_access_key.
    def recheck_secret_found(key_pairs, sts_config)
      key_pairs.each do |access_key_id, key_pair|
        if key_pair.state == :secret_found
          try_a_secret key_pair, key_pair.right_secret_access_key, sts_config
        end
      end
    end

    # For all permutations in the fast_run_data,
    # - create ak as init_empty if missing
    # - discard if state != :secret_not_found
    # - feed it the secret
    def check_new_secrets(key_pairs, fast_run_data, sts_config)
      find_permutations(fast_run_data) do |access_key_id, secret_access_key|
        key_pair = find_or_add key_pairs, access_key_id
        if key_pair.state == :secret_not_found
          try_a_secret key_pair, secret_access_key, sts_config
        end
      end
    end

    def find_permutations(fast_run_data)
      fast_run_data.each do |repo|
        repo["aws_credentials_commits"] or next
        repo["aws_credentials_commits"]["log"].each do |l|
          l["possible_secrets"]["new_permutations"].each {|ak,sk| yield ak, sk}
          l["possible_secrets"]["old_permutations"].each {|ak,sk| yield ak, sk}
        end
      end
    end

    def find_or_add(key_pairs, access_key_id)
      key_pairs[access_key_id] ||= AwsKeyPair.init_empty(access_key_id)
    end

    def try_a_secret(key_pair, secret_access_key, sts_config)
      return if key_pair.wrong_secret_access_keys and key_pair.wrong_secret_access_keys.include? secret_access_key

      begin
        config = sts_config.merge({ access_key_id: key_pair.access_key_id, secret_access_key: secret_access_key })
        user_arn = Aws::STS::Client.new(config).get_caller_identity.arn
        puts "#{key_pair.access_key_id} secret found"
        key_pair.add_secret_found(secret_access_key, user_arn, Time.now)
      rescue Aws::STS::Errors::InvalidClientTokenId
        puts "#{key_pair.access_key_id} is bad"
        key_pair.add_bad_access_key(Time.now)
      rescue Aws::STS::Errors::SignatureDoesNotMatch
        puts "#{key_pair.access_key_id} secret not found"
        key_pair.add_secret_not_found(secret_access_key)
      end
    end

  end

end
