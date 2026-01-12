require "google/apis/gmail_v1"
require "googleauth"
require "notifications/client"
require_relative "./env_token_store"

module Services
  def self.notify
    # Logic to determine which URL to use:
    # 1. If USE_NOTIFY_PIT is true, use the Env Var or default to the internal Docker URL.
    # 2. If USE_NOTIFY_PIT is false, force nil (Production) to ignore the docker-compose default.
    base_url = if ENV["USE_NOTIFY_PIT"] == "true"
                 ENV.fetch("NOTIFY_API_URL", "http://notify-pit:8000")
               else
                 nil
               end

    @notify ||= if base_url
                  # FIX: Pass base_url as a positional argument, not keyword (base_url: ...)
                  Notifications::Client.new(ENV["NOTIFY_SMOKETEST_API_KEY"], base_url)
                else
                  # If no base_url, the client defaults to the real production API
                  Notifications::Client.new(ENV["NOTIFY_SMOKETEST_API_KEY"])
                end
  end

  # Helper to access the mock service directly for retrieval (still needed for emails)
  def self.notify_pit_url
    ENV.fetch("NOTIFY_API_URL", "http://notify-pit:8000")
  end

  def self.gmail
    @gmail ||= Google::Apis::GmailV1::GmailService.new.tap do |client|
      client_id = Google::Auth::ClientId.from_hash JSON.parse(ENV["GOOGLE_API_CREDENTIALS"])
      scope = [Google::Apis::GmailV1::AUTH_GMAIL_SEND,
               Google::Apis::GmailV1::AUTH_GMAIL_MODIFY]
      token_store = EnvTokenStore.new ENV
      authorizer = Google::Auth::UserAuthorizer.new client_id,
                                                    scope,
                                                    token_store
      client.client_options.application_name = "GovWifi Smoke Tests"
      client.authorization = authorizer.get_credentials "default"
    end
  end
end