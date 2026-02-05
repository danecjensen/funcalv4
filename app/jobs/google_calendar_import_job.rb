class GoogleCalendarImportJob < ApplicationJob
  queue_as :imports

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(calendar_id)
    calendar = Calendar.find(calendar_id)

    unless calendar.google? && calendar.import_source_id.present?
      Rails.logger.info "[GoogleCalendarImportJob] Calendar #{calendar.id} is not a Google Calendar"
      return
    end

    Rails.logger.info "[GoogleCalendarImportJob] Starting import for calendar #{calendar.id}: #{calendar.import_source_id}"

    result = GoogleCalendarImportService.call(calendar)

    if result.success?
      Rails.logger.info "[GoogleCalendarImportJob] Imported #{result.event_count} events for calendar #{calendar.id}"
    else
      Rails.logger.error "[GoogleCalendarImportJob] Import failed for calendar #{calendar.id}: #{result.error}"
    end
  end
end
