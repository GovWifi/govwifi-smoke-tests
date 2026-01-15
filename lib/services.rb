require "google/apis/gmail_v1"
require "googleauth"
require "notifications/client"
require_relative "./env_token_store"

module Services
  def self.notify
    if ENV['NOTIFY_BASE_URL'] && !ENV['NOTIFY_BASE_URL'].to_s.empty?
# 1. Prepare the variables
      url = ENV['NOTIFY_BASE_URL'].to_s.strip.chomp('/')
      # We use the double-UUID key to satisfy the gem's regex validation
      key = "mock_key-00000000-0000-0000-0000-000000000000-11111111-1111-1111-1111-111111111111"

      # 2. Initialize the client (even if it ignores the URL arg, we fix it below)
      @mock_client ||= Notifications::Client.new(key, url)

      # 3. --- BRUTE FORCE FIX ---
      # Since the log proved the gem is ignoring the constructor argument,
      # we manually force the instance variable to be set.
      @mock_client.instance_variable_set(:@base_url, url)

      # 4. --- DOUBLE LOCK ---
      # We also override the method on this specific object to guarantee
      # it returns our URL, just in case the gem uses the method instead of the variable.
      def @mock_client.base_url
        ENV['NOTIFY_BASE_URL'].to_s.strip.chomp('/')
      end
      puts "Using MOCK Notify service at #{@mock_client.base_url}"
      puts "Cehcking client base_url: #{ @mock_client.instance_variable_get(:@base_url) }"
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
