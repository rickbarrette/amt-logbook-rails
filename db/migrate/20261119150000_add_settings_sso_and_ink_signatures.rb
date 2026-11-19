class AddSettingsSsoAndInkSignatures < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :settings, :key, unique: true

    add_column :users, :sso_uid, :string
    add_index :users, :sso_uid, unique: true
    add_column :sessions, :via_sso, :boolean, null: false, default: false

    # Ink-signature mode: the supervisor is written on the entry, not an account.
    add_column :work_entries, :supervisor_name, :string
    add_column :work_entries, :supervisor_certificate, :string
  end
end
