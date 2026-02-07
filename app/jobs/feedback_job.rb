class FeedbackJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 2
  discard_on ActiveRecord::RecordNotFound

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

    # 2. Pull latest code
    pull_result = exec_logged("cd /home/sprite/funcalv4 && git fetch origin && git reset --hard origin/master")
    raise "Git pull failed (exit #{pull_result[:exit_code]})" unless pull_result[:exit_code] == 0

    # 3. Run Claude Code with the feedback
    prompt = @feedback.feedback_text.gsub("'", "'\\''")
    claude_result = exec_logged(
      "cd /home/sprite/funcalv4 && claude -p '#{prompt}' --allowedTools 'Edit,Bash,Read' --output-format text",
      timeout: 900
    )
    log("Claude exit code: #{claude_result[:exit_code]}")

    # 4. Commit changes (skip if nothing changed)
    exec_logged("cd /home/sprite/funcalv4 && git add -A")
    commit_result = exec_logged(
      "cd /home/sprite/funcalv4 && git diff --cached --quiet || git commit -m 'Feedback ##{feedback_id}: #{@feedback.feedback_text.truncate(72)}'"
    )

    # 5. Push to origin
    push_result = exec_logged("cd /home/sprite/funcalv4 && git push origin master")
    raise "Git push failed (exit #{push_result[:exit_code]})" unless push_result[:exit_code] == 0

    # 6. Get commit SHA
    sha_result = exec_logged("cd /home/sprite/funcalv4 && git rev-parse HEAD")
    commit_sha = sha_result[:stdout].strip

    # 7. Deploy to Fly.io
    deploy_result = exec_logged(
      "cd /home/sprite/funcalv4 && flyctl deploy --app funcalv4 --remote-only --strategy immediate --ha=false",
      timeout: 600
    )
    raise "Deploy failed (exit #{deploy_result[:exit_code]})" unless deploy_result[:exit_code] == 0

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
    log("stdout: #{result[:stdout]}") if result[:stdout].present?
    log("stderr: #{result[:stderr]}") if result[:stderr].present?
    result
  end

  def log(message)
    @log << "[#{Time.current.iso8601}] #{message}"
  end
end
