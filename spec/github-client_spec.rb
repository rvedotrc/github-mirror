require 'github_mirror'
require 'rspec/expectations'
require 'rspec/mocks'

describe GithubMirror::GithubClient do

  it "makes a github client" do
    data = {
      "github" => {
        "user" => "u",
        "pass" => "p",
      }
    }
    auth_file = "auth.json"
    expect(IO).to receive(:read).with(auth_file).and_return(JSON.generate(data))

    mock = double "github client"
    actual = GithubMirror::GithubClient.get(auth_file)
    expect(actual.current_options[:login]).to eq("u")
    expect(actual.current_options[:password]).to eq("p")
  end

end
