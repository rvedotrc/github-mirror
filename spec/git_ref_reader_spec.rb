require 'github_mirror'

describe GithubMirror::GitRefReader do

  # By no means complete test coverage :-/
  # Also, doesn't use mocking
  it "parses refs" do
    ref_data = GithubMirror::GitRefReader.read_git_refs "."
    expect(ref_data.keys).to include("refs/heads/master")
  end

end
