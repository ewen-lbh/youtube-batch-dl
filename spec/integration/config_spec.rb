RSpec.describe "`youtube_batch_dl config` command", type: :cli do
  it "executes `youtube_batch_dl help config` command successfully" do
    output = `youtube_batch_dl help config`
    expected_output = <<-OUT
Commands:
    OUT

    expect(output).to eq(expected_output)
  end
end
