require 'youtube_batch_dl/commands/add'

RSpec.describe YoutubeBatchDL::Commands::Add do
  it "executes `add` command successfully" do
    output = StringIO.new
    tracknames = nil
    options = {}
    command = YoutubeBatchDL::Commands::Add.new(tracknames, options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
