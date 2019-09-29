RSpec.describe "`youtube_batch_dl config reset` command", type: :cli do
  it "executes `youtube_batch_dl config help reset` command successfully" do
    output = `youtube_batch_dl config help reset`
    expected_output = <<-OUT
Usage:
  youtube_batch_dl reset SETTINGS...

Options:
  -h, [--help], [--no-help]  # Display usage information

Resets SETTING(s) to its/their default value(s). If SETTING is "all", ask for confirmation and reset every setting
    OUT

    expect(output).to eq(expected_output)
  end
end
