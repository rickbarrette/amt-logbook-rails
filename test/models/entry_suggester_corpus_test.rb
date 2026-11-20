require "test_helper"

# Realistic logbook entries and the ATA chapter / category a reviewer would
# give them. When a suggestion rule changes, this shows what it fixed and
# what it broke. Several chapters are listed where reasonable people log the
# same work differently.
class EntrySuggesterCorpusTest < ActiveSupport::TestCase
  CORPUS = [
    # Inspections, records, general
    [ "Assisted with 100 hour inspection", %w[05], "general" ],
    [ "Annual inspection, opened all inspection panels and checked for corrosion", %w[05], "general" ],
    [ "Performed progressive inspection phase 2", %w[05], "general" ],
    [ "Researched and complied with recurring AD 2011-10-09, made logbook entry", %w[05], "general" ],
    [ "Dye penetrant inspection of nose gear fork", %w[05 32], nil ],
    [ "Filled out form 337 for the major repair", %w[05], "general" ],
    [ "Weighed aircraft and computed new empty weight and CG", %w[08], "general" ],
    [ "Updated weight and balance and equipment list after avionics install", %w[08], "general" ],
    [ "Jacked aircraft for gear swing", %w[32 07], "airframe" ],
    [ "Towed aircraft to wash rack", %w[09], "general" ],
    [ "Washed and waxed aircraft", %w[12], "general" ],
    [ "Serviced tires and struts with nitrogen", %w[12 32], nil ],
    [ "Lubricated flap tracks and control hinges per lube chart", %w[12 27], nil ],
    [ "Replaced missing placards in cabin", %w[11], "general" ],
    [ "Fueled aircraft and checked sumps for water", %w[12 28], nil ],
    [ "Torqued and safety wired hardware", %w[20], "general" ],
    [ "Installed helicoil in cylinder head spark plug hole", %w[74 72 20], "powerplant" ],
    [ "Fabricated new hose assembly and pressure tested", %w[20], "general" ],

    # Electrical, lights, avionics
    [ "Replaced battery and cleaned battery box corrosion", %w[24], "airframe" ],
    [ "Replaced alternator belt and adjusted tension", %w[24], nil ],
    [ "Troubleshot low voltage light, replaced voltage regulator", %w[24], nil ],
    [ "Repaired chafed wiring behind panel, installed new splices", %w[24], "airframe" ],
    [ "Replaced left nav light bulb", %w[33], "airframe" ],
    [ "Replaced strobe power supply", %w[33], "airframe" ],
    [ "Installed new LED landing light", %w[33], "airframe" ],
    [ "Replaced com antenna and coax", %w[23], "airframe" ],
    [ "Repaired pilot headset jack", %w[23], "airframe" ],
    [ "Replaced ELT battery and performed ELT test", %w[25 24], "airframe" ],
    [ "Transponder and encoder check per 91.413", %w[34], "airframe" ],
    [ "Pitot static check per 91.411", %w[34], "airframe" ],
    [ "Replaced vacuum pump", %w[37], "airframe" ],
    [ "Replaced attitude indicator", %w[34], "airframe" ],
    [ "Swung compass and updated compass card", %w[34], "airframe" ],
    [ "Autopilot pitch servo removed and sent out for repair", %w[22], "airframe" ],

    # Flight controls
    [ "Rigged ailerons and checked cable tension", %w[27], "airframe" ],
    [ "Replaced frayed rudder cable", %w[27], "airframe" ],
    [ "Adjusted elevator trim tab free play", %w[27], "airframe" ],
    [ "Replaced flap motor", %w[27], "airframe" ],
    [ "Replaced flap rollers", %w[27 57], "airframe" ],

    # Landing gear
    [ "Replaced tube left main wheel", %w[32], "airframe" ],
    [ "Assist Bleeding Brakes", %w[32], "airframe" ],
    [ "Replaced brake linings both mains", %w[32], "airframe" ],
    [ "Repacked wheel bearings", %w[32], "airframe" ],
    [ "Serviced nose strut", %w[32 12], nil ],
    [ "Replaced shimmy damper", %w[32], "airframe" ],
    [ "Performed gear swing and adjusted downlocks", %w[32], "airframe" ],
    [ "Replaced master cylinder o-rings", %w[32], "airframe" ],
    [ "Replaced torque link bushings", %w[32], "airframe" ],
    [ "Replaced tailwheel spring", %w[32], "airframe" ],

    # Fuel, hydraulics, environmental, ice
    [ "Replaced leaking fuel selector valve", %w[28], "airframe" ],
    [ "Cleaned gascolator and fuel strainer", %w[28], "airframe" ],
    [ "Resealed left fuel tank", %w[28], "airframe" ],
    [ "Replaced fuel quantity sender", %w[28], "airframe" ],
    [ "Replaced hydraulic pump", %w[29], "airframe" ],
    [ "Inspected heater muff for cracks", %w[21 05], nil ],
    [ "Repaired cabin heat cable", %w[21], "airframe" ],
    [ "Patched deice boot", %w[30], "airframe" ],
    [ "Replaced pitot heat element", %w[30 34], "airframe" ],
    [ "Replaced oxygen bottle", %w[35], "airframe" ],

    # Structures
    [ "* replaced loose oil door hinge rivets\n* installed new skin rivets at inboard flap track left side", %w[51], "airframe" ],
    [ "Stop drilled crack in right horizontal stabilizer skin", %w[51 55], "airframe" ],
    [ "Installed doubler on aft bulkhead", %w[51 53], "airframe" ],
    [ "Repaired dent in leading edge", %w[51 57], "airframe" ],
    [ "Repaired fiberglass wingtip", %w[51 57], "airframe" ],
    [ "Treated corrosion on wing spar and applied zinc chromate", %w[51 57], "airframe" ],
    [ "Recovered rudder with Polyfiber fabric", %w[51 27], "airframe" ],
    [ "Replaced windshield", %w[56], "airframe" ],
    [ "Adjusted cabin door latch", %w[52], "airframe" ],
    [ "Replaced seat track rollers", %w[25], "airframe" ],
    [ "Welded cracked exhaust stack", %w[78], "powerplant" ],

    # Propeller
    [ "Dressed prop rock chip", %w[61], "powerplant" ],
    [ "Dynamic balance of propeller", %w[61], "powerplant" ],
    [ "Replaced spinner bulkhead", %w[61], "powerplant" ],
    [ "Replaced prop governor", %w[61], "powerplant" ],

    # Engine
    [ "Assisted with reassembling cowlings", %w[71], "powerplant" ],
    [ "Replaced engine mount bushings", %w[71], "powerplant" ],
    [ "Repaired cracked baffles", %w[71], "powerplant" ],
    [ "Differential compression check all cylinders", %w[72], "powerplant" ],
    [ "Borescoped cylinders", %w[72], "powerplant" ],
    [ "Replaced #3 cylinder and piston", %w[72], "powerplant" ],
    [ "Replaced leaking rocker cover gaskets", %w[72], "powerplant" ],
    [ "Replaced pushrod tube seals", %w[72], "powerplant" ],
    [ "Compressor wash on PT6", %w[72], "powerplant" ],
    [ "Hot section inspection", %w[72], "powerplant" ],
    [ "Overhauled carburetor", %w[73], "powerplant" ],
    [ "Cleaned fuel injector nozzles", %w[73], "powerplant" ],
    [ "Adjusted idle mixture and idle speed", %w[73], "powerplant" ],
    [ "Replaced engine driven fuel pump", %w[73], "powerplant" ],
    [ "Assisted with replacement of mixture cable", %w[76], "powerplant" ],
    [ "Replaced throttle cable", %w[76], "powerplant" ],
    [ "Replaced prop control cable", %w[76], "powerplant" ],
    [ "Timed magnetos", %w[74], "powerplant" ],
    [ "Cleaned, gapped and rotated spark plugs", %w[74], "powerplant" ],
    [ "Replaced ignition harness", %w[74], "powerplant" ],
    [ "Troubleshot rough mag drop on right mag", %w[74], "powerplant" ],
    [ "Replaced induction air filter", %w[75], "powerplant" ],
    [ "Repaired carb heat box", %w[75], "powerplant" ],
    [ "Replaced CHT probe on #2", %w[77], "powerplant" ],
    [ "Replaced oil temperature sender", %w[77], "powerplant" ],
    [ "Replaced tachometer", %w[77], "powerplant" ],
    [ "Replaced muffler", %w[78], "powerplant" ],
    [ "Inspected exhaust system for cracks and leaks", %w[78], "powerplant" ],
    [ "Oil change, cut filter for inspection", %w[79], "powerplant" ],
    [ "Changed oil and filter, cleaned suction screen", %w[79], "powerplant" ],
    [ "Replaced oil cooler hoses", %w[79], "powerplant" ],
    [ "Fixed oil leak at oil filler neck", %w[79], "powerplant" ],
    [ "Replaced starter", %w[80], "powerplant" ],
    [ "Replaced starter adapter", %w[80], "powerplant" ],
    [ "Replaced turbocharger wastegate actuator", %w[81], "powerplant" ],
    [ "Ground run and leak check after engine change", %w[71], "powerplant" ],

    # Rotorcraft
    [ "Tracked and balanced main rotor", %w[62], "airframe" ],
    [ "Replaced tail rotor pitch links", %w[64 67], "airframe" ],
    [ "Inspected swashplate bearings", %w[67], "airframe" ],
    [ "Replaced tail rotor drive hanger bearings", %w[65], "airframe" ]
  ].freeze

  test "realistic entries get the chapter and category a reviewer would give" do
    misses = CORPUS.filter_map do |text, chapters, category|
      s = EntrySuggester.new.suggest(text)
      got = s && "#{s.ata_chapter}/#{s.category}"
      ok = s && chapters.include?(s.ata_chapter) && (category.nil? || s.category == category)
      "#{text.lines.first.strip.inspect}: got #{got || "nothing"}, want #{chapters.join("|")}/#{category || "any"}" unless ok
    end
    assert_empty misses, "#{misses.size} of #{CORPUS.size} entries miss:\n#{misses.join("\n")}"
  end

  test "every suggested area belongs to the suggested category or General" do
    CORPUS.each do |text, _, _|
      s = EntrySuggester.new.suggest(text) or next
      s.subject_areas.each do |code|
        assert_includes [ "general", s.category ], Faa.subject_area_section(code), "#{text.inspect}: #{code} on a #{s.category} entry"
      end
    end
  end

  test "two unrelated jobs in one entry get a hint to split them" do
    s = EntrySuggester.new.suggest("Assist Bleeding Brakes\nAssisted trouble shooting charging issues")
    assert_equal "32", s.ata_chapter
    assert_equal "24", s.also
  end

  test "parts of one job don't get the split hint" do
    [ "* replaced loose oil door hinge rivets\n* installed new skin rivets at inboard flap track left side",
      "Removed cowlings, changed oil and filter, cleaned spark plugs",
      "Replaced alternator, torqued and safety wired",
      "Assisted with 100 hour\nAdjusted mixture and idle" ].each do |text|
      assert_nil EntrySuggester.new.suggest(text).also, text
    end
  end

  test "shop practices alone don't outrank the part worked on" do
    s = EntrySuggester.new.suggest("Replaced alternator, torqued and safety wired")
    assert_equal "24", s.ata_chapter
  end
end
