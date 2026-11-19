class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :token, null: false
      t.boolean :admin, null: false, default: false
      t.boolean :technician, null: false, default: true
      t.boolean :supervisor, null: false, default: false
      t.references :invited_by, foreign_key: { to_table: :users }
      t.references :user, foreign_key: true
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :invitations, :token, unique: true

    create_table :user_certificates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :number, null: false
      t.date :expires_on
      t.timestamps
    end

    # Which supervisors may sign which technicians' entries.
    create_table :supervisions do |t|
      t.references :technician, null: false, foreign_key: { to_table: :users }
      t.references :supervisor, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :supervisions, %i[technician_id supervisor_id], unique: true

    create_table :aircraft do |t|
      t.string :n_number, null: false
      t.string :serial_number
      t.string :manufacturer
      t.string :model
      t.integer :year_manufactured
      t.string :aircraft_type
      t.string :engine_type
      t.string :engine_manufacturer
      t.string :engine_model
      t.integer :engines_count
      t.string :source, null: false, default: "manual"
      t.timestamps
    end
    add_index :aircraft, :n_number, unique: true

    # FAA Releasable Aircraft database, flattened (no owner names or addresses).
    create_table :registry_records do |t|
      t.string :n_number, null: false
      t.string :serial_number
      t.string :manufacturer
      t.string :model
      t.integer :year_manufactured
      t.string :aircraft_type
      t.string :engine_type
      t.string :engine_manufacturer
      t.string :engine_model
      t.integer :engines_count
      t.integer :seats
      t.string :status_code
    end
    add_index :registry_records, :n_number, unique: true

    create_table :registry_imports do |t|
      t.references :user, foreign_key: true
      t.string :filename
      t.integer :records_count
      t.string :status, null: false, default: "pending"
      t.text :error
      t.datetime :finished_at
      t.timestamps
    end

    create_table :work_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :aircraft, foreign_key: { to_table: :aircraft }
      t.references :supervisor, foreign_key: { to_table: :users }
      t.date :performed_on, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :minutes, null: false
      t.string :category, null: false
      t.string :ata_chapter
      t.json :subject_areas, null: false, default: []
      t.text :description, null: false
      t.string :reference
      t.string :location
      t.string :status, null: false, default: "draft"
      t.datetime :submitted_at
      t.text :returned_reason
      t.timestamps
    end
    add_index :work_entries, %i[user_id performed_on]
    add_index :work_entries, %i[supervisor_id status]

    create_table :timers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :aircraft, foreign_key: { to_table: :aircraft }
      t.references :work_entry, foreign_key: true
      t.string :category
      t.string :description
      t.datetime :started_at, null: false
      t.datetime :running_since
      t.integer :accumulated_seconds, null: false, default: 0
      t.datetime :stopped_at
      t.timestamps
    end
    add_index :timers, %i[user_id stopped_at]

    create_table :entry_signatures do |t|
      t.references :work_entry, null: false, foreign_key: true, index: { unique: true }
      t.references :user, foreign_key: true
      t.string :signer_name, null: false
      t.string :certificate_kind, null: false
      t.string :certificate_number, null: false
      t.text :statement, null: false
      t.datetime :signed_at, null: false
      t.string :content_digest, null: false
      t.text :content_snapshot, null: false
      t.string :auth_method, null: false
      t.string :ip_address
      t.string :seal, null: false
      t.timestamps
    end
  end
end
