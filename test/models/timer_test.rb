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

  test "clocking in opens a draft entry that can be filled in while the clock runs" do
    travel_to Time.zone.local(2026, 11, 1, 8, 0, 0)
    timer = Timer.start!(user: @user, aircraft: aircraft(:n12345), description: "Brakes")
    entry = timer.work_entry
    assert entry.draft?
    assert entry.clocking?
    assert_equal [ "Brakes", Date.new(2026, 11, 1), aircraft(:n12345) ], [ entry.description, entry.performed_on, entry.aircraft ]

    entry.update!(description: "Replaced left brake linings", ata_chapter: "32", category: "airframe")
    travel 97.minutes
    assert_equal entry, timer.stop!
    entry.reload
    assert_not entry.clocking?
    assert_equal [ 96, "Replaced left brake linings", "32" ], [ entry.minutes, entry.description, entry.ata_chapter ]
    assert_equal Time.zone.local(2026, 11, 1, 9, 37, 0), entry.ended_at
  end

  test "an entry can't be sent or recorded until the clock stops" do
    entry = Timer.start!(user: @user).work_entry
    assert_raises(ArgumentError) { entry.submit!(to: users(:sup)) }
    assert_raises(ArgumentError) { entry.record! }
    entry.timer.stop!
    entry.reload.submit!(to: users(:sup))
    assert entry.submitted?
  end

  test "discarding a timer removes its untouched draft" do
    timer = Timer.start!(user: @user)
    assert_difference -> { WorkEntry.count }, -1 do
      timer.discard!
    end
  end

  test "a timer started before entries opened at clock-in still makes one when stopped" do
    travel_to Time.zone.local(2026, 11, 1, 8, 0, 0)
    timer = @user.timers.create!(started_at: Time.current, running_since: Time.current, description: "Old style")
    travel 1.hour
    entry = timer.stop!
    assert_equal [ 60, "Old style" ], [ entry.minutes, entry.description ]
    assert_equal entry, timer.reload.work_entry
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
