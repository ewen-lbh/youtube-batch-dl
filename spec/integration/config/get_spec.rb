RSpec.describe "`youtube_batch_dl config get` command", type: :cli do
  it "executes `youtube_batch_dl config help get` command successfully" do
    output = `youtube_batch_dl config help get`
    expected_output = <<-OUT
Usage:
  youtube_batch_dl get SETTINGS...

Options:
  -h, [--help], [--no-help]  # Display usage information

Displays SETTING 's value(s). If SETTING is "all", display every possible setting with its value. Displays values that are still to their defaults in cyan.
    OUT

    expect(output).to eq(expected_output)
  end
end
