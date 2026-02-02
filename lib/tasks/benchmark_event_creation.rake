namespace :benchmark do
  desc "Benchmark EventCreationService performance"
  task event_creation: :environment do
    require "benchmark/ips" if defined?(Benchmark::Ips) || Gem.loaded_specs["benchmark-ips"]

    puts "\n=== EventCreationService Performance Benchmark ===\n\n"

    # Find or create test user
    user = User.first || User.create!(
      email: "benchmark@test.com",
      password: "password123",
      first_name: "Benchmark",
      last_name: "User"
    )

    # Track timing for each instrumented operation
    timings = Hash.new { |h, k| h[k] = [] }

    subscription = ActiveSupport::Notifications.subscribe(/event_creation\./) do |name, start, finish, id, payload|
      duration_ms = (finish - start) * 1000
      timings[name] << duration_ms
    end

    puts "Running iterations for each source type...\n\n"

    sources = [:manual, :api, :chat]
    iterations_per_source = 10

    sources.each do |source|
      puts "Source: #{source}"
      iterations_per_source.times do |i|
        params = {
          title: "Benchmark Event #{source} #{i} #{Time.current.to_i}",
          starts_at: (Time.current + rand(1..30).days).iso8601,
          ends_at: (Time.current + rand(1..30).days + 1.hour).iso8601,
          description: "A test event for benchmarking",
          event_type: "social",
          location: "Test Location"
        }

        result = EventCreationService.call(user: user, params: params, source: source)
        print result.success? ? "." : "F"
      end
      puts "\n"
    end

    ActiveSupport::Notifications.unsubscribe(subscription)

    puts "\n=== Detailed Timing Results ===\n\n"

    timings.each do |event_name, values|
      avg = values.sum / values.size
      min = values.min
      max = values.max
      puts "#{event_name}:"
      puts "  avg: #{avg.round(2)}ms"
      puts "  min: #{min.round(2)}ms"
      puts "  max: #{max.round(2)}ms"
      puts "  samples: #{values.size}"
      puts ""
    end

    # Cleanup benchmark events
    Event.where("title LIKE 'Benchmark Event%'").destroy_all
    puts "Cleaned up benchmark events.\n\n"

    # Additional IPS benchmark if gem is available
    if defined?(Benchmark::IPS)
      puts "=== Iterations Per Second Benchmark ===\n\n"

      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)

        x.report("EventCreationService.call (api)") do
          params = {
            title: "IPS Event #{Time.current.to_i}#{rand(10000)}",
            starts_at: (Time.current + 1.day).iso8601,
            event_type: "social"
          }
          result = EventCreationService.call(user: user, params: params, source: :api)
          result.event&.destroy if result.success?
        end

        x.compare!
      end
    else
      puts "Install benchmark-ips gem for iterations/second benchmarks."
      puts "  bundle add benchmark-ips --group development"
    end
  end
end
