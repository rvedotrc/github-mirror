require 'github_mirror'

describe GithubMirror::AwsKeyPair do

  def make_copy_of(k)
    text = JSON.generate(k.to_h)
    GithubMirror::AwsKeyPair.from_h(JSON.parse text)
  end

  it "should init wrong secret (empty)" do
    k = GithubMirror::AwsKeyPair.init_empty('ak')
    copy = make_copy_of k

    [ k, copy ].each do |what|
      expect(what.access_key_id).to eq('ak')
      expect(what.wrong_secret_access_keys).to be_empty
      expect(what.state).to eq(:secret_not_found)
    end
  end

  it "should init wrong secret" do
    k = GithubMirror::AwsKeyPair.init_secret_not_found('ak', 'sak')
    copy = make_copy_of k

    [ k, copy ].each do |what|
      expect(what.access_key_id).to eq('ak')
      expect(what.wrong_secret_access_keys).to eq(['sak'])
      expect(what.state).to eq(:secret_not_found)
    end
  end

  it "should init right secret" do
    t = Time.now
    k = GithubMirror::AwsKeyPair.init_secret_found('ak', 'sak', 'arn', t)
    copy = make_copy_of k

    [ k, copy ].each do |what|
      expect(what.access_key_id).to eq('ak')
      expect(what.right_secret_access_key).to eq('sak')
      expect(what.date_secret_found_first).to eq(Time.at(t.to_i))
      expect(what.date_secret_found_last).to eq(Time.at(t.to_i))
      expect(what.state).to eq(:secret_found)
    end
  end

  it "should init bad key" do
    t = Time.now
    k = GithubMirror::AwsKeyPair.init_bad_access_key('ak', t)
    copy = make_copy_of k

    [ k, copy ].each do |what|
      expect(what.access_key_id).to eq('ak')
      expect(what.date_bad).to eq(Time.at(t.to_i))
      expect(what.state).to eq(:bad_access_key)
    end
  end

  it "should add_secret_not_found (to secret_not_found)" do
    k = GithubMirror::AwsKeyPair.init_secret_not_found('ak', 'sak')
    k.add_secret_not_found('rak')
    k.add_secret_not_found('sak')
    k.add_secret_not_found('zak')

    expect(k.access_key_id).to eq('ak')
    expect(k.wrong_secret_access_keys).to eq(%w[ rak sak zak ])
    expect(k.state).to eq(:secret_not_found)
  end

  it "should add_secret_not_found (to secret_found)" do
    t = Time.now
    k1 = GithubMirror::AwsKeyPair.init_secret_found('ak', 'sak', 'arn', t)
    k2 = GithubMirror::AwsKeyPair.init_secret_found('ak', 'sak', 'arn', t)
    k1.add_secret_not_found('bad')
    expect(k1.to_h).to eq(k2.to_h)
  end

  it "should add_secret_not_found (to bad_access_key)" do
    t = Time.now
    k1 = GithubMirror::AwsKeyPair.init_bad_access_key('ak', t)
    k2 = GithubMirror::AwsKeyPair.init_bad_access_key('ak', t)
    k1.add_secret_not_found('bad')
    expect(k1.to_h).to eq(k2.to_h)
  end

  it "should add_secret_found (to secret_not_found)" do
    t = Time.now
    arn = "some:user:arn"
    k = GithubMirror::AwsKeyPair.init_secret_not_found('ak', 'sak')
    k.add_secret_found('good', arn, t)

    expect(k.access_key_id).to eq('ak')
    expect(k.wrong_secret_access_keys).to be_nil
    expect(k.right_secret_access_key).to eq('good')
    expect(k.date_secret_found_first).to eq(Time.at(t.to_i))
    expect(k.date_secret_found_last).to eq(Time.at(t.to_i))
    expect(k.state).to eq(:secret_found)
  end

  it "should add_secret_found (to secret_found)" do
    t1 = Time.now
    t2 = t1 + 10
    arn = "some:user:arn"
    k = GithubMirror::AwsKeyPair.init_secret_found('ak', 'sak', arn, t1)
    k.add_secret_found('sak', arn, t2)
    
    expect(k.access_key_id).to eq('ak')
    expect(k.right_secret_access_key).to eq('sak')
    expect(k.date_secret_found_first).to eq(Time.at(t1.to_i))
    expect(k.date_secret_found_last).to eq(Time.at(t2.to_i))
    expect(k.state).to eq(:secret_found)
  end

  it "should add_secret_found (to bad_access_key)" do
    t = Time.now
    k1 = GithubMirror::AwsKeyPair.init_bad_access_key('ak', t)
    k2 = GithubMirror::AwsKeyPair.init_bad_access_key('ak', t)
    k1.add_secret_found('sak', "some:user:arn", t)
    expect(k1.to_h).to eq(k2.to_h)
  end

  it "should add_bad_access_key (to secret_not_found)" do
    t = Time.now
    k = GithubMirror::AwsKeyPair.init_secret_not_found('ak', 'sak')
    k.add_bad_access_key(t)

    expect(k.access_key_id).to eq('ak')
    expect(k.wrong_secret_access_keys).to be_nil
    expect(k.date_bad).to eq(Time.at(t.to_i))
    expect(k.state).to eq(:bad_access_key)
  end

  it "should add_bad_access_key (to secret_found)" do
    t1 = Time.now
    t2 = t1 + 10
    k = GithubMirror::AwsKeyPair.init_secret_found('ak', 'sak', "some:user:arn", t1)
    k.add_bad_access_key(t2)

    expect(k.access_key_id).to eq('ak')
    expect(k.right_secret_access_key).to eq('sak') # though tbh forcibly forgetting would also work
    expect(k.date_bad).to eq(Time.at(t2.to_i))
    expect(k.state).to eq(:bad_access_key)
  end

  it "should add_bad_access_key (to bad_access_key)" do
    t1 = Time.now
    t2 = t1 + 10
    k = GithubMirror::AwsKeyPair.init_bad_access_key('ak', t1)
    k.add_bad_access_key(t2)

    expect(k.access_key_id).to eq('ak')
    expect(k.date_bad).to eq(Time.at(t1.to_i))
    expect(k.state).to eq(:bad_access_key)
  end

end
