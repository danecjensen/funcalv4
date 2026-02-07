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

    parse_exec_response(response)
  end

  def create_checkpoint(label)
    response = HTTParty.post(
      "#{BASE_URL}/sprites/#{@sprite_name}/checkpoints",
      headers: headers.merge("Content-Type" => "application/json"),
      body: { label: label }.to_json
    )

    parse_json_response(response)
  end

  def restore_checkpoint(checkpoint_id)
    response = HTTParty.post(
      "#{BASE_URL}/sprites/#{@sprite_name}/checkpoints/#{checkpoint_id}/restore",
      headers: headers
    )

    parse_json_response(response)
  end

  def list_checkpoints
    response = HTTParty.get(
      "#{BASE_URL}/sprites/#{@sprite_name}/checkpoints",
      headers: headers
    )

    parse_json_response(response)
  end

  private

  def headers
    { "Authorization" => "Bearer #{@token}" }
  end

  def parse_exec_response(response)
    data = response.parsed_response
    {
      stdout: data["stdout"].to_s,
      stderr: data["stderr"].to_s,
      exit_code: data["exit_code"] || response.code
    }
  rescue StandardError => e
    { stdout: "", stderr: "Failed to parse response: #{e.message}", exit_code: -1 }
  end

  def parse_json_response(response)
    response.parsed_response
  end
end
