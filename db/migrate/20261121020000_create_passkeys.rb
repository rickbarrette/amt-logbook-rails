class CreatePasskeys < ActiveRecord::Migration[8.1]
  def change
    create_table :passkeys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, default: 0, null: false
      t.string :name, null: false
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :passkeys, :external_id, unique: true
    add_column :users, :webauthn_id, :string
    add_index :users, :webauthn_id, unique: true
  end
end
