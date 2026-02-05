class AddImportSourceIdToCalendars < ActiveRecord::Migration[7.1]
  def change
    add_column :calendars, :import_source_id, :string
    add_index :calendars, [:user_id, :import_source, :import_source_id],
              unique: true, name: "idx_calendars_external_source",
              where: "import_source IS NOT NULL AND import_source_id IS NOT NULL"
  end
end
