require 'youtube_batch_dl/commands/config/set'

RSpec.describe YoutubeBatchDL::Commands::Config::Set do
  it "executes `config set` command successfully" do
    output = StringIO.new
    setting = nil
    value = nil
    options = {}
    command = YoutubeBatchDL::Commands::Config::Set.new(setting, value, options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
