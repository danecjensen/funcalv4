# Event Creation Profiler
#
# Subscribes to ActiveSupport::Notifications events from EventCreationService
# to help diagnose performance issues.
#
# Enable profiling by setting ENV['EVENT_CREATION_PROFILING'] = 'true'
# or in development by default.

if Rails.env.development? || ENV["EVENT_CREATION_PROFILING"] == "true"
  # Store timing data for aggregation
  Rails.application.config.after_initialize do
    %w[total dedup_check build_event save].each do |event_name|
      ActiveSupport::Notifications.subscribe("event_creation.#{event_name}") do |name, start, finish, id, payload|
        duration_ms = ((finish - start) * 1000).round(2)
        source = payload[:source] || "unknown"

        Rails.logger.info "[EventCreation] #{name} (source: #{source}): #{duration_ms}ms"

        # Also store for potential aggregation if rack-mini-profiler is present
        if defined?(Rack::MiniProfiler) && Rack::MiniProfiler.current
          Rack::MiniProfiler.current.record_timing(name, duration_ms)
        end
      end
    end
  end
end
