require "test_helper"
require "zip"

class RegistryImporterTest < ActiveSupport::TestCase
  MASTER = <<~CSV
    N-NUMBER,SERIAL NUMBER,MFR MDL CODE,ENG MFR MDL,YEAR MFR,TYPE REGISTRANT,NAME,STREET,TYPE AIRCRAFT,TYPE ENGINE,STATUS CODE,
    12345 ,17255555      ,2072738,41514,2001,1,JANE PILOT                    ,123 MAIN ST,4,1,V ,
    9AB   ,1001          ,7100510,17003,1975,1,SOMEONE ELSE                  ,1 ELM ST,6,3,V ,
  CSV
  ACFTREF = <<~CSV
    CODE,MFR,MODEL,TYPE-ACFT,TYPE-ENG,AC-CAT,BUILD-CERT-IND,NO-ENG,NO-SEATS,
    2072738,CESSNA                        ,172S              ,4,1,1,0,01,004,
    7100510,BELL                          ,206B              ,6,3,1,0,01,005,
  CSV
  ENGINE = <<~CSV
    CODE,MFR,MODEL,TYPE,HORSEPOWER,THRUST,
    41514,LYCOMING  ,IO-360-L2A  ,1 ,00180,000000,
    17003,ALLISON   ,250-C20B    ,3 ,00420,000000,
  CSV

  test "imports the registry zip without owner details and refreshes registry aircraft" do
    Aircraft.create!(n_number: "N9AB", source: "registry")
    path = Rails.root.join("tmp/registry-test-#{Process.pid}.zip")
    Zip::File.open(path, create: true) do |z|
      z.get_output_stream("MASTER.txt") { _1.write("﻿" + MASTER) }
      z.get_output_stream("ACFTREF.txt") { _1.write(ACFTREF) }
      z.get_output_stream("ENGINE.txt") { _1.write(ENGINE) }
    end

    assert_equal 2, RegistryImporter.new(path).call
    r = RegistryRecord.find_by_n_number("N12345")
    assert_equal "CESSNA", r.manufacturer
    assert_equal "172S", r.model
    assert_equal 2001, r.year_manufactured
    assert_equal "Fixed wing single engine", r.aircraft_type
    assert_equal "LYCOMING IO-360-L2A", "#{r.engine_manufacturer} #{r.engine_model}"
    assert_equal 4, r.seats
    assert_not RegistryRecord.column_names.include?("name")
    assert_equal "BELL", Aircraft.find_by(n_number: "N9AB").manufacturer
  ensure
    FileUtils.rm_f(path)
  end

  test "a file that isn't the registry is refused and keeps the current data" do
    RegistryRecord.create!(n_number: "111")
    path = Rails.root.join("tmp/registry-bad-#{Process.pid}.txt")
    File.write(path, "hello,world\n1,2\n")
    assert_raises(RegistryImporter::Error) { RegistryImporter.new(path).call }
    assert RegistryRecord.exists?(n_number: "111")
  ensure
    FileUtils.rm_f(path)
  end
end
