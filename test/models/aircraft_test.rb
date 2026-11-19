require "test_helper"

class AircraftTest < ActiveSupport::TestCase
  test "normalizes N-numbers" do
    assert_equal "N123AB", Aircraft.normalize_n_number(" n-123ab ")
    assert_equal "N54321", Aircraft.normalize_n_number("54321")
  end

  test "lookup fills details from the registry" do
    RegistryRecord.create!(n_number: "9876Z", manufacturer: "PIPER", model: "PA-28-181", year_manufactured: 1980, aircraft_type: "Fixed wing single engine")
    a = Aircraft.lookup!("n9876z")
    assert_equal "N9876Z", a.n_number
    assert_equal "PIPER", a.manufacturer
    assert_equal "registry", a.source
  end

  test "lookup of an unknown N-number creates a bare aircraft" do
    a = Aircraft.lookup!("N55555")
    assert_equal "manual", a.source
    assert_nil a.manufacturer
  end
end
