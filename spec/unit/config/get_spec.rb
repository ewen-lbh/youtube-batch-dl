require 'youtube_batch_dl/commands/config/get'

RSpec.describe YoutubeBatchDL::Commands::Config::Get do
  it "executes `config get` command successfully" do
    output = StringIO.new
    settings = nil
    options = {}
    command = YoutubeBatchDL::Commands::Config::Get.new(settings, options)

    command.execute(output: output)

    expect(output.string).to eq("OK\n")
  end
end
