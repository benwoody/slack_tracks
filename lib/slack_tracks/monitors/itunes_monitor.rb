class ITunesMonitor
  CONF = {}
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
