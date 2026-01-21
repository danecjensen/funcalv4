class AddIcalImportToCalendars < ActiveRecord::Migration[7.1]
  def change
    add_column :calendars, :import_url, :string
    add_column :calendars, :import_source, :string
    add_column :calendars, :last_imported_at, :datetime
    add_column :calendars, :import_enabled, :boolean, default: false
    add_column :calendars, :import_interval_hours, :integer, default: 6
    add_column :calendars, :import_error, :text
  end
end
