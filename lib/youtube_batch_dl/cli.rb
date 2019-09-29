# frozen_string_literal: true

require 'thor'

module YoutubeBatchDL
  # Handle the application command line parsing
  # and the dispatch to various command objects
  #
  # @api public
  class CLI < Thor
    # Error raised by this runner
    Error = Class.new(StandardError)

    desc 'version', 'youtube_batch_dl version'
    def version
      require_relative 'version'
      puts "v#{YoutubeBatchDL::VERSION}"
    end
    map %w(--version -v) => :version

    require_relative 'commands/config'
    register YoutubeBatchDL::Commands::Config, 'config', 'config [SUBCOMMAND]', 'Set SETTING to VALUE'
  end
end
