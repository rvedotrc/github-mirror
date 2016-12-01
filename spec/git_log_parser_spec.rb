require 'github_mirror'

describe GithubMirror::GitLogParser do

  def do_parse(log_file)
    yielded = []

    File.open(log_file) do |f|
      parser = GithubMirror::GitLogParser.new(f)
      parser.parse do |what|
        yielded << what
      end
    end

    yielded
  end

  # By no means complete test coverage :-/
  it "parses a simple log" do
    parsed = do_parse File.join(File.dirname(__FILE__), "simple-log.txt")

    expect(parsed.count).to eq(4)
    expect(parsed.first[:commit_lines].first).to eq("commit 4a8097c61e6d6a8d2d451e47cc689eafd4a8a598\n")
    expect(parsed.first[:file_lines].first).to eq("diff --git a/rosarium.gemspec b/rosarium.gemspec\n")
    expect(parsed.first[:hunk_lines].first).to eq("@@ -2,7 +2,7 @@\n")

    expect(parsed.map do |c|
      c[:commit_lines].first
    end).to eq([
      "commit 4a8097c61e6d6a8d2d451e47cc689eafd4a8a598\n",
      "commit e44b6a0c60730c623789c043f6ad0de2590cde1b\n",
      "commit cf972b239644a98598f588a8756f9d76d8f19441\n",
      "commit cf972b239644a98598f588a8756f9d76d8f19441\n",
    ])
  end

end
