# frozen_string_literal: true

require_relative '../../command'

module YoutubeBatchDL
  module Commands
    class Config
      class Reset < YoutubeBatchDL::Command
        def initialize(SETTINGS, options)
          @SETTINGS = SETTINGS
          @options = options
        end

        def execute(input: $stdin, output: $stdout)
          # Command logic goes here ...
          output.puts "OK"
        end
      end
    end
  end
end
