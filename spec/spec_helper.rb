require "capybara/rspec"
require "govwifi_eapoltest"
require "rotp"

Dir["../lib/*"].each { |f| require f }
Dir["./spec/support/*"].each { |f| require f }
Dir["./spec/system/*/shared_context.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.include Capybara::DSL
  config.include AuthenticationHelper
  config.include RemoveUserHelper

  config.before(:suite) do
    begin
      # This calls the method in your lib/services.rb
      client = Services.notify

      # Reach inside the Notifications::Client object to see its target URL
      # This is the "backdoor" we discussed to see the hidden @base_url
      actual_url = client.instance_variable_get(:@base_url)

      puts "\n" + ("=" * 60)
      puts "🚨 NOTIFY MOCK DIAGNOSTIC 🚨"
      puts "1. Environment Variable (NOTIFY_BASE_URL): '#{ENV['NOTIFY_BASE_URL']}'"
      puts "2. Client Internal Target:                '#{actual_url}'"
      puts "=" * 60 + "\n"

      if actual_url.to_s.include?("api.notifications.service.gov.uk")
        puts "❌ ERROR: Client is still hitting PRODUCTION!"
      else
        puts "✅ SUCCESS: Client is pointing to the MOCK."
      end
    rescue => e
      puts "❌ DIAGNOSTIC FAILED: #{e.message}"
    end
  end
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium_headless
end

Capybara.app_host = "http://admin.#{ENV['SUBDOMAIN']}.service.gov.uk"
