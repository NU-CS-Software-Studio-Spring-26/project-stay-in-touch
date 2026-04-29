class CreateGoogleCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :google_credentials do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :access_token,  null: false
      t.string :refresh_token, null: false
      t.datetime :expires_at,  null: false

      t.timestamps
    end
  end
end
