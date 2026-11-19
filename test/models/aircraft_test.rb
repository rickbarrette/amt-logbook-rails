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

class AircraftRegistryRefreshTest < ActiveSupport::TestCase
  test "aircraft added before the registry get filled; hand-typed details are kept" do
    bare = Aircraft.create!(n_number: "N11111")
    typed = Aircraft.create!(n_number: "N22222", manufacturer: "HOMEBUILT", model: "RV-7")
    RegistryRecord.create!(n_number: "11111", manufacturer: "MOONEY", model: "M20J")
    RegistryRecord.create!(n_number: "22222", manufacturer: "VANS", model: "RV-7A")
    assert_equal 1, Aircraft.refresh_from_registry!
    assert_equal "MOONEY", bare.reload.manufacturer
    assert_equal "registry", bare.source
    assert_equal "HOMEBUILT", typed.reload.manufacturer
  end

  test "lookup fills a bare aircraft that already exists" do
    Aircraft.create!(n_number: "N33333")
    RegistryRecord.create!(n_number: "33333", manufacturer: "PIPER", model: "J-3")
    assert_equal "PIPER", Aircraft.lookup!("N33333").manufacturer
  end
end
