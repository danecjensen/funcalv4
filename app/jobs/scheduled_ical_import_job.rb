class ScheduledIcalImportJob < ApplicationJob
  queue_as :scheduled

  def perform
    Rails.logger.info "[ScheduledIcalImportJob] Checking for calendars needing import sync"

    Calendar.where(import_enabled: true).find_each do |calendar|
      next unless calendar.needs_import_sync?

      Rails.logger.info "[ScheduledIcalImportJob] Queueing import for calendar #{calendar.id} (source: #{calendar.import_source})"

      if calendar.google?
        GoogleCalendarImportJob.perform_later(calendar.id)
      else
        IcalImportJob.perform_later(calendar.id)
      end
    end
  end
end
