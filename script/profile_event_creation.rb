#!/usr/bin/env ruby
# frozen_string_literal: true

# Profile EventCreationService in detail
#
# Usage:
#   bin/rails runner script/profile_event_creation.rb
#
# This script provides detailed breakdown of where time is spent
# during event creation, particularly useful for diagnosing
# slow Soleil chat event creation.

require "benchmark"

puts "\n=== EventCreationService Detailed Profiler ===\n\n"

user = User.first
unless user
  puts "No user found. Create a user first."
  exit 1
end

puts "Using user: #{user.email}\n\n"

# Sample event params (mimics chat-created event)
params = {
  title: "Profile Test Event #{Time.current.to_i}",
  starts_at: (Time.current + 1.day).iso8601,
  ends_at: (Time.current + 1.day + 1.hour).iso8601,
  description: "A test event created by the profiler script",
  event_type: "social",
  location: "Test Location"
}

puts "=== Step-by-step Breakdown ===\n\n"

# Manual step-by-step profiling
service = EventCreationService.new(user: user, params: params, source: :chat)

total_time = Benchmark.measure do
  # Step 1: Duplicate check
  dedup_time = Benchmark.measure do
    # Access private method for profiling
    service.send(:should_check_duplicates?)
  end
  puts "1. should_check_duplicates?: #{(dedup_time.real * 1000).round(2)}ms"

  # Step 2: Build event
  event = nil
  build_time = Benchmark.measure do
    # This creates the Post with ActionText body
    event = service.send(:build_event)
  end
  puts "2. build_event: #{(build_time.real * 1000).round(2)}ms"

  if event
    # Step 3: Event validation
    valid_time = Benchmark.measure do
      event.valid?
    end
    puts "3. event.valid?: #{(valid_time.real * 1000).round(2)}ms"

    # Step 4: Post save (includes ActionText)
    if event.post
      post_save_time = Benchmark.measure do
        # Don't actually save here, just measure validation overhead
        event.post.valid?
      end
      puts "4. post.valid?: #{(post_save_time.real * 1000).round(2)}ms"
    end
  end
end

puts "\nTotal service prep time: #{(total_time.real * 1000).round(2)}ms\n\n"

# Full service call profiling
puts "=== Full Service Call (with DB writes) ===\n\n"

timings = {}

subscription = ActiveSupport::Notifications.subscribe(/event_creation\./) do |name, start, finish, id, payload|
  timings[name] = (finish - start) * 1000
end

full_time = Benchmark.measure do
  @result = EventCreationService.call(user: user, params: params, source: :chat)
end

ActiveSupport::Notifications.unsubscribe(subscription)

puts "Result: #{@result.success? ? 'SUCCESS' : 'FAILURE'}"
puts "Event ID: #{@result.event&.id}"
puts "\nInstrumented timings:"
timings.each do |name, ms|
  puts "  #{name}: #{ms.round(2)}ms"
end
puts "\nTotal wall time: #{(full_time.real * 1000).round(2)}ms"

# Cleanup
if @result.success? && @result.event
  @result.event.destroy
  puts "\nCleaned up test event."
end

puts "\n=== Analysis ===\n\n"

if timings["event_creation.save"]
  save_pct = (timings["event_creation.save"] / timings["event_creation.total"] * 100).round(1)
  puts "Save operation: #{save_pct}% of total time"

  if save_pct > 80
    puts "\n*** BOTTLENECK: Save operation dominates. ***"
    puts "Likely causes:"
    puts "  - Post + ActionText (has_rich_text :body) creates multiple DB writes"
    puts "  - Transaction overhead with nested saves"
    puts ""
    puts "Potential optimizations:"
    puts "  - Consider lazy ActionText (only create when body is substantial)"
    puts "  - Use insert_all for batch event creation"
    puts "  - Cache default_user_calendar lookup"
  end
end
