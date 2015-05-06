require 'helper'

module SlackTracksTest
  class TestSlackTracks < TestCase

    def test_syscmd
      assert_equal syscmd('whoami'), "I don't know"
    end

  end
end
