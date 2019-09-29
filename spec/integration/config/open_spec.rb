RSpec.describe "`youtube_batch_dl config open` command", type: :cli do
  it "executes `youtube_batch_dl config help open` command successfully" do
    output = `youtube_batch_dl config help open`
    expected_output = <<-OUT
Usage:
  youtube_batch_dl open

Options:
  -h, [--help], [--no-help]  # Display usage information

Opens ~/.config/youtube-batch-dl/config.yaml with  (falls back to nano). Use --with/-w to explicitly specify which command should receive the path.
    OUT

    expect(output).to eq(expected_output)
  end
end
