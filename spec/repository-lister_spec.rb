require 'github_mirror'
require 'rspec/expectations'
require 'rspec/mocks'

describe GithubMirror::RepositoryLister do

  def repo_hash
    {
      "git_url" => Time.now.to_f.to_s,
      "is_private" => true,
      "pushed_at" => "2016-11-04T19:46:54Z",
    }
  end

  def repo_object(hash)
    r = double "repo"
    expect(r).to receive(:git_url).and_return(hash["git_url"])
    expect(r).to receive(:private).and_return(hash["is_private"])
    expect(r).to receive(:pushed_at).and_return(hash["pushed_at"])
    r
  end

  def setup_cached(cached_results)
    github_client = double "github client"
    json_cache = double "json cache"

    expect(json_cache).to receive(:read).and_return(cached_results)

    GithubMirror::RepositoryLister.new(github_client, json_cache)
  end

  def setup_uncached(repos_1, repos_2)
    page_1 = repos_1.map {|r| repo_object r}.to_enum
    page_2 = repos_2.map {|r| repo_object r}.to_enum

    github_client = double "github client"
    json_cache = double "json cache"

    expect(json_cache).to receive(:read).and_return(nil)

    repos = double "repos"
    expect(github_client).to receive(:repos).and_return(repos)
    expect(repos).to receive(:list).and_return(page_1)
    expect(page_1).to receive(:has_next_page?).and_return(true)
    expect(page_1).to receive(:next_page).and_return(page_2)
    expect(page_2).to receive(:has_next_page?).and_return(false)

    expect(json_cache).to receive(:write).with(repos_1.to_a + repos_2.to_a)

    GithubMirror::RepositoryLister.new(github_client, json_cache)
  end

  it "returns a single page if cache is fresh (block)" do
    cached_results = [ repo_hash, repo_hash, repo_hash ]
    lister = setup_cached cached_results

    yielded = []
    lister.each_page {|page| yielded << page}
    expect(yielded).to eq([ cached_results ])
  end

  it "returns a single page if cache is fresh (no block)" do
    cached_results = [ repo_hash, repo_hash, repo_hash ]
    lister = setup_cached cached_results

    iter = lister.each_page
    expect(iter.next).to eq(cached_results)
    expect { iter.next }.to raise_error(StopIteration)
  end

  it "returns pages via the client and updates the cache if the cache is not fresh (block)" do
    repos_1 = [ repo_hash, repo_hash, repo_hash ]
    repos_2 = [ repo_hash, repo_hash, repo_hash ]
    lister = setup_uncached repos_1, repos_2

    yielded = []
    lister.each_page {|page| yielded << page}
    expect(yielded).to eq([ repos_1, repos_2 ])
  end

  it "returns pages via the client and updates the cache if the cache is not fresh (no block)" do
    repos_1 = [ repo_hash, repo_hash, repo_hash ]
    repos_2 = [ repo_hash, repo_hash, repo_hash ]
    lister = setup_uncached repos_1, repos_2

    yielded = []
    iter = lister.each_page
    expect(iter.next).to eq(repos_1)
    expect(iter.next).to eq(repos_2)
    expect { iter.next }.to raise_error(StopIteration)
  end

end
