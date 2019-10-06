# frozen_string_literal: true
require "open-uri"
require "json"
require "rspotify"
require "dotenv"
require "fuzzy_match"
require "amatch"  # C extensions for faster fuzzy_match
FuzzyMatch.engine = :amatch
require_relative "../command"

class FileNotFound < StandardError; end

module YoutubeBatchDL
  module Commands
    class Start < YoutubeBatchDL::Command
      def initialize(files, options, config)
        @files = files
        @options = options
        @config = config
        if files.length < 1
          default = @config.fetch(:in_file)
          if !default
            raise FileNotFound, "Please specify a file in the command or add a default `in_file` setting in the config"
          else
            @files = [default]
          end
        end
        #TODO: remove duplicates with same artist & title from spotify metadata? (+ this)
        @files.uniq!
      end

      class APISearch
        def initialize()
          Dotenv.load "#{File.dirname __FILE__}/../../../.env"
          @api_keys = {
            youtube: ENV["YOUTUBE_DATA_API_KEY"],
            spotify_id: ENV["SPOTIFY_API_ID"],
            spotify_secret: ENV["SPOTIFY_API_SECRET"],
          }

          RSpotify.authenticate @api_keys[:spotify_id], @api_keys[:spotify_secret]

          @endpoints = {
            yt_search: "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&key=#{@api_keys[:youtube]}&q=%s",
            yt_video: "https://www.googleapis.com/youtube/v3/videos?part=contentDetails&key=#{@api_keys[:youtube]}&id=%s",
          }
        end

        def parse_iso8601(duration)
          match = duration.match /PT(?:([0-9]*)H)*(?:([0-9]*)M)*(?:([0-9.]*)S)*/
          hours = match[1].to_i
          minutes = match[2].to_i
          seconds = match[3].to_i
          [hours, minutes, seconds]
        end

        def iso8601_to_seconds(duration)
          hours, minutes, seconds = parse_iso8601 duration
          seconds + (minutes * 60) + (hours * 60 * 60)
        end

        def iso8601_to_human(duration)
          hours, minutes, seconds = parse_iso8601 duration
          (hours > 0 ? "#{hours}:" : "") + "#{minutes}:#{seconds}"
        end

        def get_youtube_video_duration(video_id)
          json = open(@endpoints[:yt_video] % video_id).read
          json = JSON::parse json
          duration = json["items"].first["contentDetails"]["duration"]
          [iso8601_to_seconds(duration), iso8601_to_human(duration)]
        end

        def youtube(query)
          url = @endpoints[:yt_search] % query
          json = open(url).read
          json = JSON.parse json
          # json['items'].each {|item| p item['snippet']}
          cleaned_up = []
          json["items"].each do |item|
            duration = get_youtube_video_duration(item["id"]["videoId"])
            cleaned_up << {
              :_snippet => item["snippet"],
              :title => item["snippet"]["title"],
              :description => item["snippet"]["description"],
              :image_url => item["snippet"]["thumbnails"]["default"]["url"],
              :duration => duration[1],  # human-readable
              :duration_secs => duration[0],  # total seconds
              :video_id => item["id"]["videoId"],
            }
          end
          File.open "ytdatapi-dump.json", "w" do |f| f.write(JSON.dump(cleaned_up)) end
          return cleaned_up
        end

        def spotify(query)
          tracks = RSpotify::Track.search(query)
          #TODO: add artist name check & album artist check (artists.contains for both)
          selected = tracks.keep_if { |t| t.album.album_type != "compilation" && t.album.total_tracks <= 15 }

          selected = tracks if selected.length == 0

          selected.sort! { |a, b| b.album.total_tracks <=> a.album.total_tracks }
          
          artist, title = query.split(' - ')
          album = duration = nil
          artists = [artist]

          if selected.length > 0
            album = selected.first.album.name
            duration = selected.first.duration_ms * 1000
            artists = selected.first.artists.map {|a| a.name}
          end

          return { 
            :duration => duration, 
            :artists => artists, 
            :title => title, 
            :album => album, 
            :_query => query 
          }
        end
      end

      def execute(input: $stdin, output: $stdout)
        # Command logic goes here ...
        searcher = APISearch.new
        queries.each do |query|
          track = searcher.spotify query
          if track[:duration_ms]
            output.puts "#{query} [#{track.album.name || '???'}] {#{track.album.release_date || '???'}}" if track
          end
          videos = searcher.youtube query
          videos.each do |video|
            p video[:title]
            p match_score(video, track)
          end
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

      def file_searches(filepath)
        p filepath
        filepath =~ /^\// || filepath = Dir.pwd + "/" + filepath
        lines = []
        File.open filepath, "r" do |file|
          lines << file.readlines.map(&:chomp)
        end
        return lines
      end

      def youtube_dl(url)
        exec "youtube-dl -xi --audio-format #{@options[:format]} --output #{@config.fetch :out_dir}/#{query}.%(ext)s #{url}"
      end

      def match_score(youtube, spotify)
        # Use 
        # select the right video...
        # - when not sure, ask the user
        score = 0
        puts "[checker/init]     Σ=#{score}"

        # --- duration is close to spotify's ---
        #         { 1                         if Delta <  max_seconds_delta
        # score = { Delta / max_seconds_delta if Delta >= max_seconds_delta
        #         { 0                         if Delta >= 10*max_seconds_delta
        if spotify[:duration]
          max_seconds_delta = 30
          spotify_duration = (spotify.duration_ms / 1000).floor
          youtube_duration = youtube[:duration_secs]
          duration_delta = spotify_duration - youtube_duration
          duration_score = case duration_delta.abs
          when 0..(max_seconds_delta / 2)
            1
          when (max_seconds_delta / 2)..max_seconds_delta
            duration_delta / max_seconds_delta
          else
            0
          end
          score += duration_score
          puts "[checker/duration] Σ=#{score}: |Δ|=#{duration_delta.abs} --> #{duration_score}"
        else
          score += 1
          puts "[checker/duration] No duration info to check against YouTube's."
        end

        # --- prefer channel that has the artist
        #     name as its channel name ---
        spotify[:artists].each do |artist|
          spotify_artist = artist
          youtube_artist = youtube[:channel_name]
          if spotify_artist == youtube_artist
            score = 1
            puts "[checker/artist]  Σ=#{score}: spotify_artist == youtube_artist"
          end
        end

        # --- match title ---
        # if title is of form Artist - Track (plus some optional crap), fuzzy-match Artist & Title
        # else, fallback to full title-to-title matching
        /(?<artist>.+) - (?<title>[^|\[\]]+).*/ =~ youtube[:title]
        if artist && title
          track_score = title.pair_distance_similar(spotify[:title])
          artist_score = 0
          spotify[:artists].each do |s_artist|
              artist_score += artist.pair_distance_similar(s_artist)
          end
          artist_score /= spotify[:artists].length
          title_score = (track_score + artist_score) / 2
          score *= title_score
          puts "[checker/title]    Σ=#{score.round 3}: #{artist_score.round 3} & #{track_score.round 3} --> #{title_score.round 3}"
        else
          title_score = youtube[:title].pair_distance_similar(spotify[:title])
          score *= title_score
          puts "[checker/title]    Σ=#{score.round 3}: #{title_score.round 3}"
        end

        # --- try to exclude Official Music Videos ---
        if /Official( Music)? Video/i =~ youtube[:title]
          score /= 2
          puts "[checker/isMV]     Σ=#{score.round 3}: title matches the MV rejection pattern"
        end

        puts "[checker/total]    Σ=#{score.round 3}"
        return score
      end

      def metadata(filepath, metadata)
        TagLib::MPEG::File.open filepath do |file|
          tags = file.id3v2_tag

          tags.artist = metadata[:artists].join(', ')
          tags.album = metadata[:album]
          tags.title = metadata[:title]
          #@:https://www.go4expert.com/articles/read-update-mp3-id3-tags-ruby-t29652/
        end
      end
    end
  end
end
