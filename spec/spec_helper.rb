require "capybara/rspec"
require "govwifi_eapoltest"
require "rotp"

# 1. Load all files in lib (this triggers our Traffic Controller in services.rb)
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
      if ENV['NOTIFY_BASE_URL']
      puts "\n" + ("=" * 50)
      puts "🔌 NETWORK CONNECTIVITY CHECK"
      puts "Target: #{ENV['NOTIFY_BASE_URL']}"

      begin
        # 1. Parse the URL
        uri = URI("#{ENV['NOTIFY_BASE_URL']}/health")

        # 2. Attempt a real connection (Timeout after 2 seconds)
        res = Net::HTTP.get_response(uri)

        if res.is_a?(Net::HTTPSuccess)
          puts "✅ SUCCESS: Connected to Mock! (Status: #{res.code})"
        else
          puts "❌ FAILURE: Connected, but got Status #{res.code}"
          puts "Response: #{res.body}"
        end
      rescue SocketError => e
        puts "❌ DNS ERROR: Could not resolve 'notifypit'. Is the Docker network attached?"
        puts "Error: #{e.message}"
      rescue Errno::ECONNREFUSED => e
        puts "❌ CONNECTION REFUSED: 'notifypit' is reachable, but nothing is listening on port 4567."
      rescue => e
        puts "❌ NETWORK ERROR: #{e.message}"
        puts "Backtrace: #{e.backtrace.first}"
      end
      puts "=" * 50 + "\n"
    end
  end
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium_headless
end

Capybara.app_host = "http://admin.#{ENV['SUBDOMAIN']}.service.gov.uk"