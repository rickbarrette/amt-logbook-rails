class CreateEntryImports < ActiveRecord::Migration[8.1]
  def change
    create_table :entry_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :filename
      t.text :data, null: false
      t.json :mapping, default: {}, null: false
      t.json :options, default: {}, null: false
      t.string :status, default: "pending", null: false
      t.integer :created_count, default: 0, null: false
      t.integer :skipped_count, default: 0, null: false
      t.json :problems, default: [], null: false
      t.datetime :imported_at
      t.timestamps
    end
    add_reference :work_entries, :entry_import, foreign_key: { on_delete: :nullify }
    add_column :work_entries, :import_details, :json
  end
end
