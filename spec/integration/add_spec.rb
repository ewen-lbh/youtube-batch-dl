RSpec.describe "`youtube_batch_dl add` command", type: :cli do
  it "executes `youtube_batch_dl help add` command successfully" do
    output = `youtube_batch_dl help add`
    expected_output = <<-OUT
Usage:
  youtube_batch_dl add TRACKNAMES...

Options:
  -h, [--help], [--no-help]  # Display usage information

Appends TRACKNAMES... to a file
    OUT

    expect(output).to eq(expected_output)
  end
end
