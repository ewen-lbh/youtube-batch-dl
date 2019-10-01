require 'youtube_batch_dl/commands/start'

RSpec.describe YoutubeBatchDL::Commands::Start do
  it "executes `start` command successfully" do
    output = StringIO.new
    file = nil
    options = {}
    command = YoutubeBatchDL::Commands::Start.new(file, options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
