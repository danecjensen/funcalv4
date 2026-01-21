module Calendar
  class ImportsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_calendar

    def update
      authorize @calendar, :update?

      if @calendar.update(import_params)
        # Trigger initial sync if enabled and URL is set
        IcalImportJob.perform_later(@calendar.id) if @calendar.import_enabled?
        redirect_to edit_calendar_path(@calendar, anchor: "import"), notice: "Import settings updated!"
      else
        redirect_to edit_calendar_path(@calendar, anchor: "import"), alert: @calendar.errors.full_messages.join(", ")
      end
    end

    def sync
      authorize @calendar, :update?
      IcalImportJob.perform_later(@calendar.id)
      redirect_to edit_calendar_path(@calendar, anchor: "import"), notice: "Import started! Events will appear shortly."
    end

    private

    def set_calendar
      @calendar = ::Calendar.find(params[:calendar_id])
    end

    def import_params
      params.require(:calendar).permit(:import_url, :import_source, :import_enabled, :import_interval_hours)
    end
  end
end
