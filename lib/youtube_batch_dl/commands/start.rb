# frozen_string_literal: true
require 'open-uri'
require 'json'
require 'rspotify'
require_relative '../command'

module YoutubeBatchDL
  module Commands
    class Start < YoutubeBatchDL::Command
      def initialize files, options, config
        @files = files
        @options = options
        @config = config

        @files.uniq!
      end

      class APISearch
        def initialize()
          @api_keys = {
            youtube: "AIzaSyAmyNyydF4rmCTJj3ccMz7boV80fjFmwN4",
            spotify: {
              id:     "b6ba0ee2cd66405a8adbb3069b5f2e76", 
              secret: "181dc2e5565a4b6e9d5747a608e57a4a",
            }
          }
          
          RSpotify.authenticate @api_keys[:spotify][:id], @api_keys[:spotify][:secret]

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
          selected = tracks.select {|track|
            return track unless track.album.album_type == 'compilation'
          }
          selected = selected.length ?: tracks
          tracks.sort! {|a,b| 
            return a.album.tracks_count <=> b.album.tracks_count
          }

          track = tracks.length ? 
          return track
        end
      end

      def execute(input: $stdin, output: $stdout)
        # Command logic goes here ...
        searcher = APISearch.new
        queries.each do |query| 
          track = searcher.spotify query
          p track.inspect
          output.puts "#{query} [#{track.album.name}] {#{track.album.release_date}}"
        end
      end

      def queries 
        queries = []
        @files.each do |file|
          queries << file_searches(file)
        end
        queries.flatten!.uniq!
        return queries
      end

      def file_searches filepath=nil
        filepath ||= @config.fetch :in_file
        filepath = Dir.pwd + '/' + filepath
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
