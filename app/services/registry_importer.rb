require "csv"
require "zip"

# Loads the FAA Releasable Aircraft database into registry_records.
#
# Download ReleasableAircraft.zip from
# https://www.faa.gov/licenses_certificates/aircraft_certification/aircraft_registry/releasable_aircraft_download
# and upload it under Admin → Aircraft registry. MASTER.txt is joined with
# ACFTREF.txt (make/model) and ENGINE.txt; owner names and addresses are
# not kept. A plain MASTER.txt works too (without make/model names).
class RegistryImporter
  BATCH = 5_000
  class Error < StandardError; end

  def initialize(path)
    @path = path.to_s
  end

  # Returns the number of records imported.
  def call
    Dir.mktmpdir("registry") do |dir|
      files = extract(dir)
      raise Error, "MASTER.txt not found in the upload" unless files["MASTER.TXT"]
      models = index(files["ACFTREF.TXT"]) { |r| [ r["CODE"], { mfr: r["MFR"], model: r["MODEL"], engines: r["NO-ENG"], seats: r["NO-SEATS"] } ] }
      engines = index(files["ENGINE.TXT"]) { |r| [ r["CODE"], { mfr: r["MFR"], model: r["MODEL"] } ] }
      count = import_master(files["MASTER.TXT"], models, engines)
      Aircraft.refresh_from_registry!
      count
    end
  end

  private

  def import_master(path, models, engines)
    header = File.open(path, "r:bom|utf-8", &:gets).to_s.upcase
    raise Error, "That doesn't look like the FAA MASTER file (no N-NUMBER column)" unless header.include?("N-NUMBER")
    count = 0
    RegistryRecord.transaction do
      RegistryRecord.delete_all
      batch = []
      each_row(path) do |r|
        n = r["N-NUMBER"].presence or next
        m = models[r["MFR MDL CODE"]] || {}
        e = engines[r["ENG MFR MDL"]] || {}
        batch << {
          n_number: n.upcase, serial_number: r["SERIAL NUMBER"], manufacturer: m[:mfr], model: m[:model],
          year_manufactured: r["YEAR MFR"].to_i.nonzero?, aircraft_type: RegistryRecord::AIRCRAFT_TYPES[r["TYPE AIRCRAFT"]],
          engine_type: RegistryRecord::ENGINE_TYPES[r["TYPE ENGINE"]], engine_manufacturer: e[:mfr], engine_model: e[:model],
          engines_count: m[:engines].to_i.nonzero?, seats: m[:seats].to_i.nonzero?, status_code: r["STATUS CODE"]
        }
        count += flush(batch) if batch.size >= BATCH
      end
      count += flush(batch)
    end
    count
  end

  def flush(batch)
    return 0 if batch.empty?
    RegistryRecord.insert_all(batch.uniq { _1[:n_number] }, unique_by: :n_number)
    batch.size.tap { batch.clear }
  end

  # Unzips into dir; returns { "MASTER.TXT" => path, ... }.
  def extract(dir)
    return { "MASTER.TXT" => @path } unless File.binread(@path, 4) == "PK\x03\x04".b
    Zip::File.open(@path) do |zip|
      zip.entries.select(&:file?).each_with_object({}) do |e, h|
        name = File.basename(e.name).upcase
        next unless name.end_with?(".TXT")
        dest = File.join(dir, name)
        File.open(dest, "wb") { |f| IO.copy_stream(e.get_input_stream, f) }
        h[name] = dest
      end
    end
  end

  def index(path)
    return {} unless path
    h = {}
    each_row(path) { |r| k, v = yield(r); h[k] = v if k }
    h
  end

  def each_row(path)
    converter = ->(h) { h.to_s.delete_prefix("\uFEFF").strip.upcase }
    CSV.foreach(path, headers: true, liberal_parsing: true, encoding: "bom|utf-8", invalid: :replace, header_converters: converter) do |row|
      yield row.to_h.transform_values { _1.to_s.scrub.strip.presence }
    end
  rescue CSV::MalformedCSVError, ArgumentError => e
    raise Error, "Couldn't read the file: #{e.message}"
  end
end
