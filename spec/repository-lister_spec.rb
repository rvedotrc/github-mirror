require 'github_mirror'
require 'rspec/expectations'
require 'rspec/mocks'

describe GithubMirror::RepositoryLister do

  it "returns a single page if cache is fresh (block)" do
    github_client = double "github client"
    json_cache = double "json cache"

    cached_results = [ 4, 5, 6 ]
    expect(json_cache).to receive(:read).and_return(cached_results)

    lister = GithubMirror::RepositoryLister.new(github_client, json_cache)
    yielded = []
    lister.each_page {|page| yielded << page}
    expect(yielded).to eq([ cached_results ])
  end

  it "returns pages via the client and updates the cache if the cache is not fresh (block)" do
    github_client = double "github client"
    json_cache = double "json cache"

    page_1 = [ 1, 2, 3 ].to_enum
    page_2 = [ 4, 5, 6 ].to_enum
    expect(json_cache).to receive(:read).and_return(nil)

    repos = double "repos"
    expect(github_client).to receive(:repos).and_return(repos)
    expect(repos).to receive(:list).and_return(page_1)
    expect(page_1).to receive(:has_next_page?).and_return(true)
    expect(page_1).to receive(:next_page).and_return(page_2)
    expect(page_2).to receive(:has_next_page?).and_return(false)

    expect(json_cache).to receive(:write).with([ 1, 2, 3, 4, 5, 6 ])

    lister = GithubMirror::RepositoryLister.new(github_client, json_cache)
    yielded = []
    lister.each_page {|page| yielded << page}
    expect(yielded).to eq([ page_1, page_2 ])
  end

end
