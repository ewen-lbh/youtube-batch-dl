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

    def initialize(*)
      super
      config_dir   = '/home/ewen/.config/youtube-batch-dl'
      config_name  = 'config'
      config_ext   = '.yaml'
      @config_path = config_dir + '/' + config_name + config_ext

      # Create directory if it does not exist
      FileUtils.mkdir_p config_dir

      # Create the config file if it does not exist
      File.open @config_path, 'a' do |f| end

      # Init config
      @config = TTY::Config.new
      @config.filename = config_name
      @config.extname  = config_ext
      @config.append_path config_dir

      # Default values
      @config.set :out_dir, value: "/home/#{ENV['USER']}"

      # Read the config
      @config.read
    end

    desc 'version', 'youtube_batch_dl version'
    def version
      require_relative 'version'
      puts "v#{YoutubeBatchDL::VERSION}"
    end
    map %w(--version -v) => :version

    require_relative 'commands/config'
    register YoutubeBatchDL::Commands::Config, 'config', 'config [SUBCOMMAND]', 'Manage the configuration file'

    desc 'start FILES...', 'search, download and apply metadata from file(s) containing list(s) of tracks'
    method_option :help, aliases: '-h', type: :boolean,
                         desc: 'Display usage information'
    method_option :video_mode, aliases: '-v', type: :boolean,
                               desc: 'Shortcut for --video and --no-metadata'
    method_option :video, type: :boolean,
                          desc: 'Downloads as a .mp4'
    method_option :metadata, type: :boolean, default: true,
                             desc: 'Apply metadata.'
    method_option :format, aliases: ['-f', '--as'], type: :string, default: 'mp3', enum: ['mp3', 'mp4', 'm4a', 'wav', 'flac', 'ogg'],
                           desc: 'Specify the format used to download the file.'
    def start(*files)
      if options[:help]
        invoke :help, ['start']
      else
        require_relative 'commands/start'
        YoutubeBatchDL::Commands::Start.new(files, options, @config).execute
      end
    end

    desc 'add TRACKNAMES...', 'Appends TRACKNAMES... to a file (uses the `in_file` setting as a default)'
    method_option :to, aliases: '-t', type: :string, default: '',
                       desc: 'Specify which file to append TRACKNAMES... to'
    def add(*tracknames)
      require_relative 'commands/add'
      YoutubeBatchDL::Commands::Add.new(tracknames, options).execute
    end
  end
end
