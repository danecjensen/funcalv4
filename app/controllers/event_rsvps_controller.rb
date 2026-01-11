class EventRsvpsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  # POST /events/:event_id/rsvp
  def create
    @rsvp = @event.rsvps.find_or_initialize_by(user: current_user)
    @rsvp.status = rsvp_params[:status]
    @rsvp.note = rsvp_params[:note]

    respond_to do |format|
      if @rsvp.save
        format.html { redirect_to event_path(@event), notice: "RSVP saved!" }
        format.turbo_stream
        format.json { render json: rsvp_json(@rsvp), status: :ok }
      else
        format.html { redirect_to event_path(@event), alert: @rsvp.errors.full_messages.join(", ") }
        format.json { render json: { errors: @rsvp.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /events/:event_id/rsvp
  def destroy
    @rsvp = @event.rsvps.find_by(user: current_user)

    respond_to do |format|
      if @rsvp&.destroy
        format.html { redirect_to event_path(@event), notice: "RSVP removed" }
        format.turbo_stream
        format.json { head :no_content }
      else
        format.html { redirect_to event_path(@event), alert: "No RSVP found" }
        format.json { head :not_found }
      end
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def rsvp_params
    params.require(:rsvp).permit(:status, :note)
  end

  def rsvp_json(rsvp)
    {
      id: rsvp.id,
      event_id: rsvp.event_id,
      user_id: rsvp.user_id,
      status: rsvp.status,
      note: rsvp.note,
      created_at: rsvp.created_at.iso8601
    }
  end
end
