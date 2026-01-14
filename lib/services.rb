require "google/apis/gmail_v1"
require "googleauth"
require "notifications/client"
require_relative "./env_token_store"

module Services
  def self.notify
    puts" Using Notify Base URL: #{ENV["NOTIFY_BASE_URL"]}"
    @notify ||= Notifications::Client.new(
      ENV["NOTIFY_SMOKETEST_API_KEY"],
      ENV["NOTIFY_BASE_URL"])
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
