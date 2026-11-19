class CreateAirports < ActiveRecord::Migration[8.1]
  def change
    # OurAirports reference data (the same source SAM and AirTrail use).
    create_table :airports do |t|
      t.string :ident, null: false
      t.string :code, null: false # ICAO-style code for logging (e.g. K1B9 for FAA 1B9)
      t.string :gps_code
      t.string :local_code
      t.string :iata
      t.string :name, null: false
      t.string :kind
      t.string :municipality
      t.string :region
      t.string :country
      t.float :latitude
      t.float :longitude
      t.timestamps
    end
    add_index :airports, :ident, unique: true
    add_index :airports, :code
    add_index :airports, :gps_code
    add_index :airports, :local_code
    add_index :airports, :iata

    create_table :airport_updates do |t|
      t.string :status, null: false, default: "pending"
      t.integer :created_count
      t.integer :updated_count
      t.integer :removed_count
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end
end
