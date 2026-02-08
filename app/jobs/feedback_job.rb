class FeedbackJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  SPRITE_PREAMBLE = "source ~/.bashrc && cd /home/sprite/funcalv4".freeze

  def perform(feedback_id)
    @feedback = Feedback.find(feedback_id)
    @log = []
    @client = SpriteClient.new

    @feedback.update!(status: "running", started_at: Time.current)

    # 1. Create checkpoint before making changes
    checkpoint = @client.create_checkpoint("pre-feedback-#{feedback_id}")
    checkpoint_id = checkpoint&.dig("id")
    @feedback.update!(checkpoint_id: checkpoint_id) if checkpoint_id
    log("Checkpoint created: #{checkpoint_id}")
    save_log!

    # 2. Pull latest code
    exec_logged!("#{SPRITE_PREAMBLE} && git fetch origin && git reset --hard origin/master && echo SUCCESS")
    save_log!

    # 3. Run Claude Code with the feedback
    prompt = @feedback.feedback_text.gsub("'", "'\\''")
    exec_logged(
      "#{SPRITE_PREAMBLE} && claude -p '#{prompt}' --allowedTools 'Edit,Bash,Read' --output-format text",
      timeout: 900
    )
    save_log!

    # 4. Commit changes (skip if nothing changed)
    exec_logged("#{SPRITE_PREAMBLE} && git add -A && (git diff --cached --quiet && echo 'No changes to commit' || git commit -m 'Feedback ##{feedback_id}: #{@feedback.feedback_text.truncate(72)}')")
    save_log!

    # 5. Push to origin
    exec_logged!("#{SPRITE_PREAMBLE} && git push origin master && echo PUSH_SUCCESS")
    save_log!

    # 6. Get commit SHA
    sha_result = exec_logged("#{SPRITE_PREAMBLE} && git rev-parse HEAD")
    commit_sha = sha_result[:stdout].strip.lines.last&.strip

    # 7. Deploy to Fly.io
    exec_logged!("#{SPRITE_PREAMBLE} && flyctl deploy --app funcalv4 --remote-only --strategy immediate --ha=false && echo DEPLOY_SUCCESS", timeout: 600)

    # 8. Mark success
    @feedback.update!(
      status: "success",
      commit_sha: commit_sha,
      agent_log: @log.join("\n"),
      completed_at: Time.current
    )

    Rails.logger.info "[FeedbackJob] Completed feedback ##{feedback_id} with commit #{commit_sha}"
  rescue StandardError => e
    @log ||= []
    @log << "ERROR: #{e.message}"
    @feedback&.update(
      status: "failed",
      agent_log: @log.join("\n"),
      completed_at: Time.current
    )
    Rails.logger.error "[FeedbackJob] Failed feedback ##{feedback_id}: #{e.message}"
    raise
  end

  private

  def exec_logged(command, timeout: 600)
    log("$ #{command}")
    result = @client.exec(command, timeout: timeout)
    log("output: #{result[:stdout]}") if result[:stdout].present?
    result
  end

  # Like exec_logged but raises if the output doesn't contain the expected SUCCESS marker
  def exec_logged!(command, timeout: 600)
    result = exec_logged(command, timeout: timeout)
    unless result[:stdout]&.include?("SUCCESS")
      raise "Command failed: #{command.truncate(100)}\nOutput: #{result[:stdout].to_s.truncate(500)}"
    end
    result
  end

  def log(message)
    @log << "[#{Time.current.iso8601}] #{message}"
  end

  def save_log!
    @feedback.update_column(:agent_log, @log.join("\n"))
  end
end
