require "test_helper"

class AirportDataTest < ActiveSupport::TestCase
  CSV_TEXT = <<~CSV
    "id","ident","type","name","latitude_deg","longitude_deg","elevation_ft","continent","iso_country","iso_region","municipality","scheduled_service","gps_code","iata_code","local_code"
    1,"KPVD","large_airport","Rhode Island T. F. Green International Airport",41.73,-71.42,55,"NA","US","US-RI","Providence","yes","KPVD","PVD","PVD"
    2,"1B9","small_airport","Mansfield Municipal Airport",42.0,-71.19,122,"NA","US","US-MA","Mansfield","no","K1B9","","1B9"
  CSV

  test "sync, lookup and search" do
    path = Rails.root.join("tmp/airports-#{Process.pid}.csv")
    File.write(path, CSV_TEXT)
    assert_equal({ created: 2, updated: 0, removed: 0 }, AirportData.sync!(path))
    assert_equal "K1B9", Airport.lookup("1B9").code
    assert_equal "KPVD", Airport.lookup("PVD").code
    assert_equal "KPVD", Airport.search("provid").first.code
    assert_equal({ created: 0, updated: 0, removed: 0 }, AirportData.sync!(path))
  ensure
    FileUtils.rm_f(path)
  end
end
