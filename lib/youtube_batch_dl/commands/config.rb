# frozen_string_literal: true
require 'fileutils'
require 'tty-config'
require 'thor'

module YoutubeBatchDL
  module Commands
    class Config < Thor

      namespace :config

      def initialize(*)
        super
        config_dir   = '~/.config/youtube-batch-dl'
        config_name  = 'config'
        config_ext   = '.yaml'
        @config_path = config_dir + '/' + config_name + config_ext

        # Create directory if it does not exist
        FileUtils.mkdir_p config_dir

        # Init config
        @config = TTY::Config.new
        @config.filename = config_name
        @config.extname  = config_ext
        @config.append_path = config_dir

        # Default values
        @config.set(:out_dir, value: '~')
      end

      desc 'open', 'Opens ~/.config/youtube-batch-dl/config.yaml'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      method_option :with, aliases: ['-w=EDITOR'], type: :string, default: ENV['EDITOR'] || 'nano',
                           desc: 'Explicitly specify which command should receive the path.'
      def open(*)
        if options[:help]
          invoke :help, ['open']
        else
          require_relative 'config/open'
          YoutubeBatchDL::Commands::Config::Open.new(options).execute
        end
      end

      desc 'reset SETTINGS...', 'Resets SETTING(s) to its/their default value(s). If SETTING is "all", ask for confirmation and reset every setting'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def reset(*settings)
        if options[:help]
          invoke :help, ['reset']
        else
          require_relative 'config/reset'
          YoutubeBatchDL::Commands::Config::Reset.new(settings, options).execute
        end
      end

      desc 'get SETTINGS...', "Displays SETTING 's value(s). If SETTING is \"all\", display every possible setting with its value. Displays values that are still to their defaults in cyan."
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def get(*settings)
        if options[:help]
          invoke :help, ['get']
        else
          require_relative 'config/get'
          YoutubeBatchDL::Commands::Config::Get.new(settings, options).execute
        end
      end

      desc 'set SETTING VALUE', 'Set SETTING to VALUE'
      method_option :help, aliases: '-h', type: :boolean,
                           desc: 'Display usage information'
      def set(setting, value)
        if options[:help]
          invoke :help, ['set']
        else
          require_relative 'config/set'
          YoutubeBatchDL::Commands::Config::Set.new(setting, value, options).execute
        end
      end
    end
  end
end
