# frozen_string_literal: true

require_relative '../command'

module YoutubeBatchDL
  module Commands
    class Add < YoutubeBatchDL::Command
      def initialize(tracknames, options)
        @tracknames = tracknames
        @options = options
      end

      def execute(input: $stdin, output: $stdout)
        # Command logic goes here ...
        output.puts "OK"
      end
    end
  end
end
