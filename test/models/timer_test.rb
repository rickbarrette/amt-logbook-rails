require "test_helper"

class TimerTest < ActiveSupport::TestCase
  setup { @user = users(:tech) }

  test "elapsed time comes from server timestamps, so it runs while the app is closed" do
    travel_to Time.zone.local(2026, 11, 1, 8, 0, 0)
    timer = Timer.start!(user: @user, description: "Brakes")
    travel 2.hours
    assert_equal 7200, timer.reload.elapsed_seconds
  end

  test "pause banks the time and resume continues" do
    travel_to Time.zone.local(2026, 11, 1, 8, 0, 0)
    timer = Timer.start!(user: @user)
    travel 30.minutes
    timer.pause!
    travel 1.hour
    assert_equal 1800, timer.elapsed_seconds
    timer.resume!
    travel 15.minutes
    assert_equal 2700, timer.elapsed_seconds
  end

  test "starting a timer pauses the one running" do
    first = Timer.start!(user: @user)
    second = Timer.start!(user: @user)
    assert first.reload.paused?
    assert second.running?
    assert_equal second, @user.running_timer
  end

  test "stop makes a draft entry rounded to tenths of an hour" do
    travel_to Time.zone.local(2026, 11, 1, 8, 0, 0)
    timer = Timer.start!(user: @user, aircraft: aircraft(:n12345), category: "airframe", description: "Brake job")
    travel 97.minutes # 1.62 h -> 1.6 h
    entry = timer.stop!
    assert entry.draft?
    assert_equal 96, entry.minutes
    assert_equal "airframe", entry.category
    assert_equal aircraft(:n12345), entry.aircraft
    assert_equal users(:sup), entry.supervisor # the only supervisor is preselected
    assert timer.reload.stopped?
  end
end
