class UpdateEventsForRangeTypes < ActiveRecord::Migration[7.1]
  def change
    # Enable btree_gist extension for GiST index support on range types
    enable_extension "btree_gist"

    change_table :events do |t|
      # Add PostgreSQL tstzrange for time range queries with native overlap support
      t.tstzrange :occurs_at

      # Store timezone explicitly for display purposes
      t.string :timezone

      # Duration as PostgreSQL interval type
      t.interval :duration
    end

    # GiST index for efficient range queries (overlap, containment, etc.)
    add_index :events, :occurs_at, using: :gist, name: "index_events_on_occurs_at_gist"

    # Populate occurs_at from existing starts_at/ends_at data
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE events
          SET occurs_at = tstzrange(starts_at, COALESCE(ends_at, starts_at + interval '1 hour'), '[)')
          WHERE starts_at IS NOT NULL;
        SQL
      end
    end
  end
end
