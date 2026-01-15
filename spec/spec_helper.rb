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
      client = Services.notify
      internal_url = client.instance_variable_get(:@base_url)
      service_id = client.instance_variable_get(:@service_id)

      puts "\n" + ("=" * 60)
      puts "🔍 NOTIFY CLIENT INSPECTION"
      puts "ENV URL:         #{ENV['NOTIFY_BASE_URL'].inspect}"
      puts "Internal Target: #{internal_url.inspect}"
      puts "Service ID:      #{service_id.inspect}"
      puts "=" * 60 + "\n"

      if internal_url.to_s.empty?
        puts "❌ ERROR: Client is NOT storing the base URL."
      elsif internal_url.to_s.include?("api.notifications.service.gov.uk")
        puts "❌ ERROR: Client is pointing to PRODUCTION."
      else
        puts "✅ SUCCESS: Client is configured for Mock."
      end
    rescue => e
      puts "❌ DIAGNOSTIC CRASHED: #{e.message}"
    end
  end
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium_headless
end

Capybara.app_host = "http://admin.#{ENV['SUBDOMAIN']}.service.gov.uk"
