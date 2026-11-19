require "test_helper"

class MarkdownTextTest < ActiveSupport::TestCase
  test "plain text for print" do
    md = "### Work\n* replaced **loose** rivets\n- used `MS20470AD4` per [AC 43.13](https://example.com)\n1. step one"
    assert_equal "Work\n• replaced loose rivets\n• used MS20470AD4 per AC 43.13\n1. step one", MarkdownText.plain(md)
  end

  test "plain text leaves ordinary text alone" do
    assert_equal "Torqued to 20 in-lbs * 2 bolts", MarkdownText.plain("Torqued to 20 in-lbs * 2 bolts")
  end
end
