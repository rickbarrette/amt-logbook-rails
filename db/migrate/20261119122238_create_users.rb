class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.boolean :admin, null: false, default: false
      t.boolean :technician, null: false, default: true
      t.boolean :supervisor, null: false, default: false
      t.string :time_zone
      # Technician: which rating(s) the experience is for (14 CFR 65.77(b)).
      t.string :rating_goal, null: false, default: "both"
      t.date :experience_started_on

      t.string :otp_secret
      t.datetime :otp_enabled_at
      t.datetime :otp_last_used_at
      t.json :otp_recovery_codes

      t.integer :failed_sign_ins, null: false, default: 0
      t.datetime :locked_until
      t.datetime :disabled_at
      t.datetime :last_signed_in_at
      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
