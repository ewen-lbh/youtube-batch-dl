# frozen_string_literal: true
require 'open-uri'
require 'json'
require 'rspotify'
require 'dotenv'
require_relative '../command'

class FileNotFound < StandardError; end

module YoutubeBatchDL
  module Commands
    class Start < YoutubeBatchDL::Command
      def initialize files, options, config
        @files = files
        @options = options
        @config = config
        if files.length < 1
          default = @config.fetch(:in_file)
          if !default
            raise FileNotFound, "Please specify a file in the command or add a default `in_file` setting in the config"
          else
            @files = [ default ]
          end
        end
        #TODO: remove duplicates with same artist & title from spotify metadata? (+ this)
        @files.uniq!
      end

      class APISearch
        def initialize()
          Dotenv.load "#{File.dirname __FILE__}/../../../.env"
          @api_keys = {
            youtube: ENV['YOUTUBE_DATA_API_KEY'],
            spotify_id: ENV['SPOTIFY_API_ID'], 
            spotify_secret: ENV['SPOTIFY_API_SECRET'],
          }
          
          RSpotify.authenticate @api_keys[:spotify_id], @api_keys[:spotify_secret]

          @endpoints = {
            youtube: "https://www.googleapis.com/youtube/v3/search?part=snippet&key=#{@api_keys[:youtube]}&q=%s"
          }
        end

        def youtube query
          url  = @endpoints[:youtube] % query
          json = open(url).read
          return JSON.parse(json)
        end

        def spotify query
          tracks = RSpotify::Track.search(query)
          selected = tracks.keep_if {|t| t.album.album_type != 'compilation' && t.album.total_tracks <= 15} #TODO: add artist name check & album artist check (artists.contains for both)
          
          selected.length > 0 || selected = tracks

          selected.sort! {|a,b| b.album.total_tracks <=> a.album.total_tracks }
          
          return selected.length ? selected.first : nil
        end
      end

      def execute(input: $stdin, output: $stdout)
        # Command logic goes here ...
        searcher = APISearch.new
        queries.each do |query| 
          track = searcher.spotify query
          output.puts "#{query} [#{track.album.album_type}||#{track.album.name}] {#{track.album.release_date}}" if track
        end
      end

      def queries 
        queries = []
        @files.each do |file|
          queries << file_searches(file)
        end
        queries.flatten!
        queries.uniq!
        return queries
      end

      def file_searches filepath
        p filepath
        filepath =~ /^\// || filepath = Dir.pwd + '/' + filepath
        lines = []
        File.open filepath, 'r' do |file|
          lines << file.readlines.map(&:chomp)
        end
        return lines
      end

      def youtube_dl url
        exec "youtube-dl -xi --audio-format #{@options[:format]} --output #{@config.fetch :out_dir}/#{query}.%(ext)s #{url}"
      end

      def metadata filepath, metadata
        TagLib::MPEG::File.open filepath do |file|
          tags = file.id3v2_tag

          tags.artist = metadata.artist.name
          tags.album  = metadata.album.name
          tags.title  = metadata.title
          #@:https://www.go4expert.com/articles/read-update-mp3-id3-tags-ruby-t29652/
        end
      end
    end
  end
end
