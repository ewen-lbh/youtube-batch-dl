require 'youtube_batch_dl/commands/config/open'

RSpec.describe YoutubeBatchDL::Commands::Config::Open do
  it "executes `config open` command successfully" do
    output = StringIO.new
    options = {}
    command = YoutubeBatchDL::Commands::Config::Open.new(options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
