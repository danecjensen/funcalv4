class IcalImportJob < ApplicationJob
  queue_as :imports

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(calendar_id)
    calendar = Calendar.find(calendar_id)

    unless calendar.import_url.present?
      Rails.logger.info "[IcalImportJob] No import URL for calendar #{calendar.id}"
      return
    end

    Rails.logger.info "[IcalImportJob] Starting import for calendar #{calendar.id}: #{calendar.import_url}"

    result = IcalImportService.call(calendar)

    if result.success?
      Rails.logger.info "[IcalImportJob] Imported #{result.event_count} events for calendar #{calendar.id}"
    else
      Rails.logger.error "[IcalImportJob] Import failed for calendar #{calendar.id}: #{result.error}"
    end
  end
end
