require "google/apis/gmail_v1"
require "googleauth"
require "notifications/client"
require_relative "./env_token_store"

module Services
  def self.notify
    # Force the mock URL and use a dummy key format that the gem accepts
    base_url = ENV['NOTIFY_BASE_URL'] || "http://notifypit:4567"
    api_key = "mock_key-00000000-0000-0000-0000-000000000000-11111111-1111-1111-1111-111111111111"

    @mock_notify ||= Notifications::Client.new(api_key, base_url)
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