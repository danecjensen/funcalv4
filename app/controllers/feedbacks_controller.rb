class FeedbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create], if: -> { request.format.json? || !user_signed_in? }
  before_action :authenticate_user!, except: [:create]
  before_action :authenticate_for_create!, only: [:create]
  before_action :set_feedback, only: [:show, :revert, :retry]

  def index
    @feedbacks = Feedback.recent
  end

  def show
  end

  def create
    @feedback = Feedback.new(feedback_params)

    if @feedback.save
      FeedbackJob.perform_later(@feedback.id)

      respond_to do |format|
        format.html { redirect_to feedbacks_path, notice: "Feedback submitted." }
        format.json { render json: { success: true, id: @feedback.id, status: @feedback.status }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to feedbacks_path, alert: @feedback.errors.full_messages.join(", ") }
        format.json { render json: { success: false, error: @feedback.errors.full_messages.join(", "), errors: @feedback.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def revert
    unless @feedback.checkpoint_id.present?
      redirect_to @feedback, alert: "No checkpoint available to revert."
      return
    end

    client = SpriteClient.new
    client.restore_checkpoint(@feedback.checkpoint_id)

    # Redeploy after restoring
    result = client.exec("cd /home/sprite/funcalv4 && git push origin master --force")
    deploy_result = client.exec("cd /home/sprite/funcalv4 && flyctl deploy --app funcalv4 --remote-only --strategy immediate --ha=false")

    @feedback.update!(status: "reverted", agent_log: [@feedback.agent_log, "--- REVERT ---", result[:stdout], deploy_result[:stdout]].compact.join("\n"))
    redirect_to @feedback, notice: "Reverted successfully."
  end

  def retry
    @feedback.update!(status: "pending", agent_log: nil, commit_sha: nil, started_at: nil, completed_at: nil)
    FeedbackJob.perform_later(@feedback.id)
    redirect_to @feedback, notice: "Feedback re-queued."
  end

  private

  def set_feedback
    @feedback = Feedback.find(params[:id])
  end

  def feedback_params
    # Map 'message' to 'feedback_text' if present
    feedback_data = params.require(:feedback).permit(
      :feedback_text,
      :message,
      :submitted_by,
      :email,
      :page_url,
      :page_path,
      :page_title,
      :user_agent,
      :screen_size,
      :viewport_size
    )

    # Use 'message' as 'feedback_text' if feedback_text is not provided
    if feedback_data[:message].present? && feedback_data[:feedback_text].blank?
      feedback_data[:feedback_text] = feedback_data[:message]
    end

    feedback_data
  end

  def authenticate_for_create!
    return if user_signed_in?

    expected = ENV["FEEDBACK_AUTH_TOKEN"]
    provided = request.headers["Authorization"]&.sub(/^Bearer\s+/, "")

    unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
