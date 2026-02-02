# Seed demo calendars for the public demo page
# Run with: bin/rails runner db/seeds/demo_calendars.rb

puts "Creating demo calendars..."

# Find or create a system user for demo calendars
demo_user = User.find_by(email: "demo@funcal.com") || User.create!(
  email: "demo@funcal.com",
  password: SecureRandom.hex(16),
  first_name: "FunCal",
  last_name: "Demo",
  admin: true
)

# Theme colors for demo calendars
DEMO_CALENDARS = [
  {
    name: "Austin Community Events",
    description: "Local events, meetups, and gatherings in Austin, TX",
    color: "#2ECC71",
    events: [
      { title: "Saturday Farmers Market", starts_at: 1.week.from_now.beginning_of_week + 9.hours, event_type: "community", location: "Mueller Lake Park" },
      { title: "Live Music at Stubbs", starts_at: 2.weeks.from_now.beginning_of_week + 5.days + 20.hours, event_type: "social", location: "Stubb's BBQ" },
      { title: "Yoga in the Park", starts_at: 3.days.from_now.beginning_of_day + 7.hours, event_type: "community", location: "Zilker Park" },
      { title: "Food Truck Friday", starts_at: 5.days.from_now.beginning_of_day + 17.hours, event_type: "social", location: "Barton Springs" }
    ]
  },
  {
    name: "Tech Meetups",
    description: "Local tech community events, workshops, and networking",
    color: "#3498DB",
    events: [
      { title: "Ruby on Rails Meetup", starts_at: 1.week.from_now.beginning_of_week + 2.days + 18.hours + 30.minutes, event_type: "meeting", location: "Capital Factory" },
      { title: "AI/ML Workshop", starts_at: 2.weeks.from_now.beginning_of_week + 10.hours, event_type: "workshop", location: "ACC Highland" },
      { title: "Startup Happy Hour", starts_at: 10.days.from_now.beginning_of_day + 17.hours + 30.minutes, event_type: "social", location: "The Driskill" }
    ]
  },
  {
    name: "Family Fun",
    description: "Kid-friendly events and family activities",
    color: "#E74C3C",
    events: [
      { title: "Story Time at Library", starts_at: 4.days.from_now.beginning_of_day + 10.hours, event_type: "community", location: "Austin Central Library" },
      { title: "Kids Art Workshop", starts_at: 1.week.from_now.beginning_of_week + 6.days + 14.hours, event_type: "workshop", location: "HOPE Outdoor Gallery" },
      { title: "Family Movie Night", starts_at: 2.weeks.from_now.beginning_of_week + 4.days + 19.hours, event_type: "celebration", location: "Alamo Drafthouse" }
    ]
  }
]

DEMO_CALENDARS.each do |cal_data|
  calendar = Calendar.find_or_create_by!(user: demo_user, name: cal_data[:name]) do |cal|
    cal.description = cal_data[:description]
    cal.color = cal_data[:color]
  end

  # Publish the calendar for public visibility
  calendar.publish unless calendar.published?

  # Create events
  cal_data[:events].each do |event_data|
    unless calendar.events.exists?(title: event_data[:title])
      calendar.events.create!(
        title: event_data[:title],
        starts_at: event_data[:starts_at],
        ends_at: event_data[:starts_at] + 2.hours,
        event_type: event_data[:event_type],
        location: event_data[:location],
        description: "Demo event for #{cal_data[:name]}"
      )
    end
  end

  puts "  Created calendar: #{calendar.name} with #{calendar.events.count} events"
end

puts "Done! Demo calendars are ready."
