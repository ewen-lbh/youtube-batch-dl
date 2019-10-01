# frozen_string_literal: true

require_relative '../../command'

module YoutubeBatchDL
  module Commands
    class Config
      class Reset < YoutubeBatchDL::Command
        def initialize(settings, options, config_obj)
          @settings = settings
          @options = options
          @config = config_obj
        end

        def execute(input: $stdin, output: $stdout)
          # Command logic goes here ...
          @settings.each do |setting|
            cur_val = @config.fetch setting
            @config.delete setting
            @config.write force: true
            output.puts "#{setting} reset to default."
          end
        end
      end
    end
  end
end
