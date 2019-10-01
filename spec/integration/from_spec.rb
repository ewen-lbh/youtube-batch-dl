RSpec.describe "`youtube_batch_dl start` command", type: :cli do
  it "executes `youtube_batch_dl help start` command successfully" do
    output = `youtube_batch_dl help start`
    expected_output = <<-OUT
Usage:
  youtube_batch_dl start FILES...

Options:
  -h, [--help], [--no-help]  # Display usage information

Starts up the searching/downloading/metadata tagging process, using tracks specified in FILE.
    OUT

    expect(output).to eq(expected_output)
  end
end
