# frozen_string_literal: true
require 'nokogiri'
require 'uri'
require 'yaml'
require 'json'
require 'open-uri'
require_relative '../command'

module Bytdlff
  module Commands
    class Music < Bytdlff::Command
      def initialize(search_term, options)
        @search_term = search_term
        @options = options
      end

      def get_searches filepath
        file = File.open filepath
        return file.readlines.map(&:chomp)
      end

      def get_api_key
        return "AIzaSyAmyNyydF4rmCTJj3ccMz7boV80fjFmwN4"
      end

      def get_youtube_search_api_url search
        return "https://www.googleapis.com/youtube/v3/search?q=#{search}&part=snippet&key=#{get_api_key}"
      end

      def get_youtube_video_url video_id
        return "https://youtube.com/watch?v=#{video_id}"
      end

      def youtube_search search
        url = get_youtube_search_api_url search
        p url
        raw = open url
        json = raw.read
        File.open 'api-dump.json', 'w' do |file|
          file.write json
        end
        return json
      end

      def parse_search_results raw_json
        File.open './yaml-test.json', 'w' do |file|
          file.write raw_json
        end
        videos = JSON.parse raw_json
        videos = videos['items']
        return videos
      end

      def run_youtube_dl url
        filepath = "/mnt/c/Users/ASUS/Desktop/%(title)s.%(ext)s"
        out = `youtube-dl -x --audio-format=mp3 --output "#{filepath}" "#{url}"`
        p out
      end
    end
  end
end
