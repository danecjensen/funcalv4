module EventsHelper
  # Generate time slot options for event forms
  # Returns array of [display_text, value] pairs for 48 half-hour slots
  #
  # Example:
  #   time_slot_options
  #   # => [["12:00 AM", "00:00"], ["12:30 AM", "00:30"], ["1:00 AM", "01:00"], ...]
  #
  def time_slot_options
    (0..23).flat_map do |hour|
      [0, 30].map do |minute|
        time = Time.zone.local(2000, 1, 1, hour, minute)
        display = time.strftime("%l:%M %p").strip
        value = time.strftime("%H:%M")
        [display, value]
      end
    end
  end

  # Return a reasonable default time (next half hour from now)
  def default_event_time
    now = Time.current
    minutes = now.min >= 30 ? 0 : 30
    hour = now.min >= 30 ? now.hour + 1 : now.hour
    hour = hour % 24
    format("%02d:%02d", hour, minutes)
  end
end
