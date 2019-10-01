# frozen_string_literal: true

require_relative '../../command'

module YoutubeBatchDL
  module Commands
    class Config
      class Set < YoutubeBatchDL::Command
        def initialize(setting, value, options, config_obj)
          @setting = setting
          @value = value
          @options = options
          @config = config_obj
        end

        def execute(input: $stdin, output: $stdout)
          old_val = @config.fetch @setting
          @config.set @setting, value: @value
          @config.write force: true
          output.puts "#{@setting}: #{old_val} → #{@value}"
        end
      end
    end
  end
end
