require "net/http"
require "uri"
require "json"

module Api
  module V1
    class ChatController < BaseController
      include ActionController::Live

      CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
      CLAUDE_MODEL = "claude-sonnet-4-20250514"

      def create
        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no" # Disable nginx buffering

        user = api_user
        unless user
          send_sse_event({ error: "Authentication required" })
          return
        end

        message = params[:message]
        conversation = params[:conversation] || []

        unless message.present?
          send_sse_event({ error: "Message is required" })
          return
        end

        stream_claude_response(user, message, conversation)
      ensure
        response.stream.close
      end

      private

      def stream_claude_response(user, message, conversation)
        api_key = ENV["ANTHROPIC_API_KEY"] || Rails.application.credentials.dig(:anthropic, :api_key)

        unless api_key
          send_sse_event({ error: "Claude API key not configured" })
          return
        end

        # Build messages array with conversation history
        messages = build_messages(conversation, message)

        # Loop to handle tool use - Claude may need multiple turns
        loop do
          result = call_claude_api(api_key, user, messages)

          break if result[:error]
          break unless result[:tool_use]

          # Execute the tool
          tool_use = result[:tool_use]
          tool_result = execute_tool(tool_use, user)

          # Add assistant's tool use message and tool result to conversation
          tool_input = begin
            JSON.parse(tool_use[:input])
          rescue JSON::ParserError
            {}
          end

          messages << {
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: tool_use[:id],
                name: tool_use[:name],
                input: tool_input
              }
            ]
          }

          messages << {
            role: "user",
            content: [
              {
                type: "tool_result",
                tool_use_id: tool_use[:id],
                content: tool_result.to_json
              }
            ]
          }

          # Continue the loop to get Claude's response to the tool result
        end

        send_sse_event({ done: true })
      rescue => e
        Rails.logger.error "Chat streaming error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        send_sse_event({ error: "Streaming error: #{e.message}" })
      end

      def call_claude_api(api_key, user, messages)
        uri = URI.parse(CLAUDE_API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = ENV["SSL_CERT_FILE"] if ENV["SSL_CERT_FILE"]
        if Rails.env.development? && !ENV["SSL_CERT_FILE"]
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        http.read_timeout = 60

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["x-api-key"] = api_key
        request["anthropic-version"] = "2023-06-01"

        request.body = {
          model: CLAUDE_MODEL,
          max_tokens: 1024,
          system: system_prompt(user),
          messages: messages,
          tools: calendar_tools,
          stream: true
        }.to_json

        result = { tool_use: nil, error: nil }
        current_tool_use = nil

        http.request(request) do |response|
          unless response.is_a?(Net::HTTPSuccess)
            error_body = response.body
            Rails.logger.error "Claude API error: #{response.code} - #{error_body}"
            send_sse_event({ error: "Claude API error: #{response.code}" })
            result[:error] = true
            return result
          end

          buffer = ""

          response.read_body do |chunk|
            buffer += chunk

            while (line_end = buffer.index("\n"))
              line = buffer.slice!(0..line_end).strip

              next if line.empty?
              next unless line.start_with?("data: ")

              data = line[6..]
              next if data == "[DONE]"

              begin
                event = JSON.parse(data)
                process_claude_event(event, current_tool_use) do |evt_result|
                  if evt_result[:tool_use_start]
                    current_tool_use = evt_result[:tool_use_start]
                  elsif evt_result[:tool_use_complete]
                    result[:tool_use] = current_tool_use
                    current_tool_use = nil
                  elsif evt_result[:content]
                    send_sse_event(evt_result)
                  elsif evt_result[:error]
                    send_sse_event(evt_result)
                    result[:error] = true
                  end
                end
              rescue JSON::ParserError => e
                Rails.logger.debug "Skipping non-JSON chunk: #{data[0..50]}"
              end
            end
          end
        end

        result
      end

      def process_claude_event(event, current_tool_use)
        case event["type"]
        when "content_block_start"
          block = event.dig("content_block")
          if block["type"] == "tool_use"
            yield({ tool_use_start: { id: block["id"], name: block["name"], input: "" } })
          end
        when "content_block_delta"
          delta = event.dig("delta")
          if delta["type"] == "text_delta"
            yield({ content: delta["text"] })
          elsif delta["type"] == "input_json_delta" && current_tool_use
            current_tool_use[:input] += delta["partial_json"] || ""
          end
        when "content_block_stop"
          if current_tool_use
            yield({ tool_use_complete: true })
          end
        when "message_stop"
          # Message complete
        when "error"
          yield({ error: event.dig("error", "message") || "Unknown error" })
        end
      end

      def execute_tool(tool_use, user)
        return nil unless tool_use

        begin
          input = JSON.parse(tool_use[:input])
        rescue JSON::ParserError
          input = {}
        end

        case tool_use[:name]
        when "create_event"
          create_event_tool(user, input)
        when "list_events"
          list_events_tool(user, input)
        when "search_events"
          search_events_tool(user, input)
        else
          { type: "error", message: "Unknown tool: #{tool_use[:name]}" }
        end
      end

      def create_event_tool(user, input)
        result = EventCreationService.call(
          user: user,
          params: {
            title: input["title"],
            starts_at: input["starts_at"] || input["date"],
            ends_at: input["ends_at"],
            location: input["location"],
            description: input["description"],
            all_day: input["all_day"] || false,
            event_type: input["event_type"] || "social",
            calendar_id: input["calendar_id"]
          },
          source: :chat
        )

        if result.success?
          {
            type: "event_created",
            event: {
              id: result.event.id,
              title: result.event.title,
              starts_at: result.event.starts_at&.iso8601,
              location: result.event.location
            }
          }
        else
          { type: "error", message: result.errors.join(", ") }
        end
      end

      def list_events_tool(user, input)
        start_date = input["start_date"] ? Date.parse(input["start_date"]) : Date.today
        end_date = input["end_date"] ? Date.parse(input["end_date"]) : start_date + 7.days

        events = Event
          .where(starts_at: start_date.beginning_of_day..end_date.end_of_day)
          .order(starts_at: :asc)
          .limit(20)

        {
          type: "events_list",
          date_range: "#{start_date.strftime('%B %d')} to #{end_date.strftime('%B %d, %Y')}",
          count: events.count,
          message: events.empty? ? "No events found in this date range." : "Found #{events.count} event(s).",
          events: events.map { |e|
            {
              id: e.id,
              title: e.title,
              starts_at: e.starts_at&.strftime("%A, %B %d at %l:%M %p"),
              location: e.location
            }
          }
        }
      end

      def search_events_tool(user, input)
        events = Event
          .where("title ILIKE :q OR description ILIKE :q OR venue ILIKE :q", q: "%#{input['query']}%")
          .order(starts_at: :asc)
          .limit(10)

        {
          type: "search_results",
          query: input["query"],
          count: events.count,
          message: events.empty? ? "No events found matching '#{input['query']}'." : "Found #{events.count} event(s) matching '#{input['query']}'.",
          events: events.map { |e|
            {
              id: e.id,
              title: e.title,
              starts_at: e.starts_at&.strftime("%A, %B %d at %l:%M %p"),
              location: e.location
            }
          }
        }
      end

      def send_sse_event(data)
        response.stream.write("data: #{data.to_json}\n\n")
      rescue IOError => e
        Rails.logger.debug "Client disconnected: #{e.message}"
      end

      def build_messages(conversation, current_message)
        messages = conversation.map do |msg|
          { role: msg["role"], content: msg["content"] }
        end
        messages << { role: "user", content: current_message }
        messages
      end

      def system_prompt(user)
        <<~PROMPT
          You are a helpful calendar assistant for FunCal, a social calendar app.
          You help users manage their events and discover interesting things to do.

          The current user is: #{user.display_name}
          Today's date is: #{Date.today.strftime("%A, %B %d, %Y")}
          Current time is: #{Time.current.strftime("%l:%M %p")}

          You can:
          1. Create events - When the user wants to add something to their calendar
          2. List events - Show upcoming events in a date range
          3. Search events - Find events by keyword

          When creating events:
          - Parse natural language dates/times (e.g., "tomorrow at 3pm", "next Friday")
          - Always confirm what you created
          - Use the create_event tool

          When listing events:
          - Default to the next 7 days if no date range specified
          - Format times in a friendly way
          - Use the list_events tool

          Be concise and helpful. Don't be overly chatty.
        PROMPT
      end

      def calendar_tools
        [
          {
            name: "create_event",
            description: "Create a new calendar event for the user",
            input_schema: {
              type: "object",
              properties: {
                title: { type: "string", description: "Event title" },
                starts_at: { type: "string", description: "Event start date/time in ISO 8601 format" },
                ends_at: { type: "string", description: "Event end date/time in ISO 8601 format (optional)" },
                location: { type: "string", description: "Event location (optional)" },
                description: { type: "string", description: "Event description (optional)" },
                all_day: { type: "boolean", description: "Whether this is an all-day event" },
                event_type: { type: "string", enum: %w[social meeting workshop community celebration], description: "Type of event" },
                calendar_id: { type: "integer", description: "Calendar ID to add the event to (uses default calendar if not specified)" }
              },
              required: ["title", "starts_at"]
            }
          },
          {
            name: "list_events",
            description: "List upcoming events in a date range",
            input_schema: {
              type: "object",
              properties: {
                start_date: { type: "string", description: "Start date in YYYY-MM-DD format" },
                end_date: { type: "string", description: "End date in YYYY-MM-DD format" }
              }
            }
          },
          {
            name: "search_events",
            description: "Search for events by keyword",
            input_schema: {
              type: "object",
              properties: {
                query: { type: "string", description: "Search query" }
              },
              required: ["query"]
            }
          }
        ]
      end
    end
  end
end
