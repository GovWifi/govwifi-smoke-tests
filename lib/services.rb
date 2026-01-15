require "google/apis/gmail_v1"
require "googleauth"
require "notifications/client"
require_relative "./env_token_store"

module Services
  def self.notify
    if ENV['NOTIFY_BASE_URL'] && !ENV['NOTIFY_BASE_URL'].to_s.empty?
      env_url = ENV['NOTIFY_BASE_URL']
      clean_url = env_url.to_s.strip.chomp('/')
      fake_key  = "mock_key-00000000-0000-0000-0000-000000000000-11111111-1111-1111-1111-111111111111"

      puts "\n--- [Services.rb] INITIALIZING MOCK ---"
      puts "URL passed to Gem: '#{clean_url}'"
      puts "Key passed to Gem: '#{fake_key}'"

      # 3. Create the client
      @mock_client ||= Notifications::Client.new(fake_key, clean_url)

      # 4. DEBUG: Check if it stuck
      actual_url = @mock_client.instance_variable_get(:@base_url)
      puts "Resulting Client URL: '#{actual_url}'"
      puts "---------------------------------------\n"

      return @mock_client
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
