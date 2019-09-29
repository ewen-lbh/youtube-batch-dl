# frozen_string_literal: true
require_relative '../../command'

module YoutubeBatchDL
  module Commands
    class Config
      class Open < YoutubeBatchDL::Command
        def initialize(options)
          @options = options
        end

        def execute(input: $stdin, output: $stdout)
          editor = @options['with']
          output.puts "Opening #{@config_path} with #{editor}..."
          exec "#{editor} #{@config_path}"
        end
      end
    end
  end
end
