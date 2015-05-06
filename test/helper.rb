require 'minitest/autorun'
$:.unshift File.expand_path('../lib', __FILE__)

module SlackTracksTest
  superclass = if defined?(Minitest::Test)
                 Minitest::Test
               else
                 MiniTest::Unit::TestCase
               end

  class TestCase < superclass
    require 'slack_tracks'
  end
end
