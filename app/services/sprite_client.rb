class SpriteClient
  BASE_URL = "https://api.sprites.dev/v1".freeze

  def initialize(sprite_name: ENV.fetch("SPRITE_NAME"), token: ENV.fetch("SPRITES_TOKEN"))
    @sprite_name = sprite_name
    @token = token
  end

  def exec(command, timeout: 600)
    response = HTTParty.post(
      "#{BASE_URL}/sprites/#{@sprite_name}/exec",
      headers: headers,
      query: { cmd: command },
      timeout: timeout
    )

    # API returns raw stdout as application/octet-stream
    {
      stdout: response.body.to_s,
      stderr: "",
      exit_code: response.success? ? 0 : response.code
    }
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    { stdout: "", stderr: "Request failed: #{e.message}", exit_code: -1 }
  end

  def create_checkpoint(comment)
    response = HTTParty.post(
      "#{BASE_URL}/sprites/#{@sprite_name}/checkpoint",
      headers: headers.merge("Content-Type" => "application/json"),
      body: { comment: comment }.to_json,
      timeout: 120
    )

    parse_streamed_response(response)
  end

  def restore_checkpoint(checkpoint_id)
    response = HTTParty.post(
      "#{BASE_URL}/sprites/#{@sprite_name}/checkpoints/#{checkpoint_id}/restore",
      headers: headers,
      timeout: 120
    )

    parse_streamed_response(response)
  end

  def list_checkpoints
    response = HTTParty.get(
      "#{BASE_URL}/sprites/#{@sprite_name}/checkpoints",
      headers: headers
    )

    response.parsed_response
  end

  private

  def headers
    { "Authorization" => "Bearer #{@token}" }
  end

  def parse_streamed_response(response)
    # API returns newline-delimited JSON events
    lines = response.body.to_s.lines.map(&:strip).reject(&:empty?)
    last_event = lines.reverse.find { |l| l.start_with?("{") }
    return {} unless last_event

    data = JSON.parse(last_event)
    # Extract checkpoint ID from the "complete" event data
    if data["data"]&.match?(/v\d+/)
      id = data["data"][/v\d+/]
      { "id" => id, "data" => data["data"] }
    else
      data
    end
  rescue JSON::ParserError
    { "data" => response.body.to_s }
  end
end
