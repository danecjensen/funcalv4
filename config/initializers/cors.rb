# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin requests.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Allow any origin for Bearer token API access
  allow do
    origins "*"

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"],
      credentials: false
  end

  # Allow Chrome extensions to make requests
  allow do
    origins "chrome-extension://*"

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end

  # Allow localhost for development (with credentials for session auth)
  allow do
    origins "http://localhost:3000", "http://127.0.0.1:3000"

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
