class FirecrawlExtractJob < ApplicationJob
  queue_as :imports

  retry_on StandardError, wait: :polynomially_longer, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(calendar_id)
    calendar = Calendar.find(calendar_id)
    calendar.update!(extraction_status: "processing")

    Rails.logger.info "[FirecrawlExtractJob] Starting extraction for calendar #{calendar.id}: #{calendar.import_url}"

    result = FirecrawlExtractService.call(
      url: calendar.import_url,
      prompt: calendar.extraction_prompt
    )

    if result.success?
      save_events(calendar, result.events)
      calendar.update!(
        extraction_status: "completed",
        last_imported_at: Time.current,
        import_error: nil
      )
      Rails.logger.info "[FirecrawlExtractJob] Extracted #{result.events.size} events for calendar #{calendar.id}"
    else
      calendar.update!(
        extraction_status: "failed",
        import_error: result.error
      )
      Rails.logger.error "[FirecrawlExtractJob] Extraction failed for calendar #{calendar.id}: #{result.error}"
    end
  end

  private

  def save_events(calendar, events)
    events.each do |event_data|
      event_params = {
        title: event_data["title"],
        starts_at: event_data["starts_at"],
        ends_at: event_data["ends_at"],
        location: event_data["location"],
        venue: event_data["venue"],
        description: event_data["description"],
        event_type: event_data["event_type"] || "social",
        image_url: event_data["image_url"],
        source_url: event_data["source_url"],
        source_name: "firecrawl",
        calendar_id: calendar.id
      }.compact

      result = EventCreationService.call(
        source: :scraper,
        user: calendar.user,
        params: event_params
      )

      if result.success?
        if result.duplicate?
          Rails.logger.info "[FirecrawlExtractJob] Skipped duplicate: #{event_data['title']}"
        else
          Rails.logger.info "[FirecrawlExtractJob] Created event: #{event_data['title']}"
        end
      else
        Rails.logger.warn "[FirecrawlExtractJob] Failed to create event '#{event_data['title']}': #{result.errors.join(', ')}"
      end
    end
  end
end
