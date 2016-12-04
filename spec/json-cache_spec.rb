require 'github_mirror'
require 'rspec/expectations'
require 'rspec/mocks'

describe GithubMirror::JSONCache do

  it "should return nil if no file" do
    file = "t.json"
    max_age = 60
    c = GithubMirror::JSONCache.new(file, max_age)
    expect(File).to receive(:open).with(file).and_raise(Errno::ENOENT)
    expect(c.read).to be_nil
  end

  it "should return nil if file is too old" do
    file = "t.json"
    max_age = 60
    c = GithubMirror::JSONCache.new(file, max_age)
    f = double "filehandle"
    expect(File).to receive(:open).with(file).and_yield(f)
    expect(f).to receive(:mtime).and_return(Time.now - max_age - 1)
    expect(c.read).to be_nil
  end

  it "should return the parsed contents if file is not too old" do
    data = { "some" => "data" }
    file = "t.json"
    max_age = 60
    c = GithubMirror::JSONCache.new(file, max_age)
    f = double "filehandle"
    expect(File).to receive(:open).with(file).and_yield(f)
    expect(f).to receive(:mtime).and_return(Time.now - max_age + 1)
    expect(f).to receive(:read).and_return(JSON.generate(data))
    expect(c.read).to eq(data)
  end

  it "should save the file via rename" do
    data = { "some" => "data" }
    contents = "..."
    expect(JSON).to receive(:generate).with(data).and_return(contents)

    file = "t.json"
    max_age = 60
    c = GithubMirror::JSONCache.new(file, max_age)

    tmp_file = file + ".tmp"
    expect(IO).to receive(:write).with(tmp_file, contents + "\n")
    expect(File).to receive(:rename).with(tmp_file, file)

    c.write(data)
  end

  it "provides JsonCache as an alias" do
    expect(GithubMirror::JsonCache).to eq(GithubMirror::JSONCache)
  end

end
