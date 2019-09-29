require 'youtube_batch_dl/commands/config/reset'

RSpec.describe YoutubeBatchDL::Commands::Config::Reset do
  it "executes `config reset` command successfully" do
    output = StringIO.new
    SETTINGS = nil
    options = {}
    command = YoutubeBatchDL::Commands::Config::Reset.new(SETTINGS, options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
