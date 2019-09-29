RSpec.describe "`youtube_batch_dl config set` command", type: :cli do
  it "executes `youtube_batch_dl config help set` command successfully" do
    output = `youtube_batch_dl config help set`
    expected_output = <<-OUT
Usage:
  youtube_batch_dl set SETTING VALUE

Options:
  -h, [--help], [--no-help]  # Display usage information

Set SETTING to VALUE
    OUT

    expect(output).to eq(expected_output)
  end
end
