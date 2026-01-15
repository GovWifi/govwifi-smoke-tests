require "google/apis/gmail_v1"
require "googleauth"
require "notifications/client"
require_relative "./env_token_store"

module Services
  def self.notify
    if ENV['NOTIFY_BASE_URL'] && !ENV['NOTIFY_BASE_URL'].to_s.empty?
      # --- MOCK LOGIC ---
      url = ENV['NOTIFY_BASE_URL'].to_s.strip.chomp('/')
      # Double-UUID key to satisfy the gem's internal validation
      key = "mock_key-00000000-0000-0000-0000-000000000000-11111111-1111-1111-1111-111111111111"
      puts "Using MOCK Notify service at #{url}"
      @mock_client ||= Notifications::Client.new(key, url)
    else
      # --- PROD LOGIC ---
      puts "Using PROD Notify service"
      @prod_notify ||= Notifications::Client.new(ENV["NOTIFY_SMOKETEST_API_KEY"])
    end
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
