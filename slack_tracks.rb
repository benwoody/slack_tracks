#!/usr/bin/env ruby

require "addressable/uri"
require "colorize"
require "google-search"
require "rest-client"
require "yaml"

def syscmd(cmd)
  `#{cmd}`.chomp
end

def load_config
  fn = "#{ENV['HOME']}/.slack.conf"
  group_key = :slack_tracks
  ex_webhook_url = 'http://hooks.slack.com/services/yadda/foo/bar/baz'

  begin
    conf = YAML.load_file(fn)
  rescue Errno::ENOENT
    File.open(fn, 'w') do |f|
      f.write({
        slack_tracks: {
          webhook: ex_webhook_url,
          username: syscmd('whoami')
        }
      }.to_yaml)
    end

    retry
  end

  conf = conf[:slack_tracks]

  if conf[:webhook] == ex_webhook_url
    $stderr.write("Please edit #{fn}!".red)
    $stderr.write("\n\nYou must change :slack_tracks[:webhook] to match the\n")
    $stderr.write("INCOMING WEBHOOK URL for your channel's integration!\n")
    exit 1
  end

  conf
end

CONF = load_config

def is_running?(app_name)
  syscmd("osascript -e 'tell application \"System Events\" to (name of processes) contains \"#{app_name}\"'") == 'true'
end

def tell_itunes(cmd)
  if is_running?("iTunes")
    syscmd("osascript -e 'tell application \"iTunes\" to #{cmd}'")
  end
end

def get_player_status
  tell_itunes('player state')
end

def playing?
  get_player_status == 'playing'
end

def get_player_position
  tell_itunes('player position').to_f
end

def get_track_database_id
  tell_itunes('database id of current track')
end

def get_track_duration
  tell_itunes('duration of current track').to_f
end

def get_track_name
  tell_itunes('name of current track')
end

def get_track_artist
  tell_itunes('artist of current track')
end

def get_track_album
  tell_itunes('album of current track')
end

def itunes_is_muted?
  (tell_itunes 'mute') == 'true'
end

def itunes_volume
  (tell_itunes 'sound volume').to_i
end

def system_is_muted?
  syscmd("osascript -e 'output muted of (get volume settings)'") == 'true'
end

def system_volume
  syscmd("osascript -e 'output volume of (get volume settings)'").to_f
end

def has_sound?
  system_is_muted? == false && itunes_is_muted? == false && system_volume > 0 && itunes_volume > 0
end

def get_itms_url(params={})
  uri = Addressable::URI.new
  uri.query_values = params
  "itms://phobos.apple.com/WebObjects/MZSearch.woa/wa/advancedSearchResults?#{uri.query}"
end

def clear_text(len)
  print "\b" * len + " " * len + "\b" * len
end

def wait_for(msg, test)
  full_msg = "Waiting for #{msg}".yellow
  len = full_msg.length

  if not test.call
    print full_msg
    sleep 1 while not test.call
    clear_text(len)
  end
end

def wait_for_app(app_name)
  wait_for("#{app_name} to run", -> { is_running?(app_name) })
end

def wait_for_apps(app_names)
  app_names.each{ |app_name| wait_for_app(app_name) }
end

class ITunesMonitor
  def initialize(attrs={})
    @testing = !! attrs[:testing]
    @sent_message = false
    @username = CONF[:username]
    @last_database_id = nil
  end

  def monitor
    while true do
      check
      sleep 1
    end
  end

  def check
    wait_for_apps(["iTunes", "Slack"])
    wait_for("iTunes to play", -> { playing? })

    position = get_player_position
    track_duration = get_track_duration
    track_database_id = get_track_database_id

    if @last_database_id != track_database_id
      @sent_message = false
      @last_database_id = track_database_id
    elsif @testing || (@sent_message == false && position > track_duration * 0.67 && playing?)
      console_emoji = '🔇 '

      track_name = get_track_name
      track_artist = get_track_artist
      track_album = get_track_album

      if has_sound?
        console_emoji = '🎵 '

        song_url = get_itms_url('artistTerm': track_artist, 'songTerm': track_name)
        artist_url = get_itms_url('artistTerm': track_artist)

        msg = "<#{artist_url}|#{track_artist}> - <#{song_url}|#{track_name}>"
        msg << "\n#{Google::Search::Image.new(:query => "#{track_artist} #{track_album}").first.uri}"
        RestClient.post(CONF[:webhook], payload: {
          username: @username,
          icon_emoji: ':itunes:',
          text: msg
        }.to_json)
      end

      puts "#{console_emoji} #{Time.now.strftime("%H:%M:%S")} : #{track_artist.bold} - #{track_name.bold}"
      @sent_message = true
    end
  end
end

ITunesMonitor.new(testing: false).monitor
