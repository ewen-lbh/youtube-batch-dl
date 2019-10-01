# frozen_string_literal: true

require_relative '../../command'

module YoutubeBatchDL
  module Commands
    class Config
      class Get < YoutubeBatchDL::Command
        def initialize(settings, options, config_obj)
          @settings = settings
          @options = options
          @config = config_obj
        end

        def execute(input: $stdin, output: $stdout)
          # Command logic goes here ...
          @settings.each do |setting|
            value = @config.fetch setting
            output.puts "#{setting}: #{value}"
          end
        end
      end
    end
  end
end
