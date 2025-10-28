require "capybara/rspec"
require "govwifi_eapoltest"
require "rotp"

Dir["../lib/*"].each { |f| require f }
Dir["./spec/support/*"].each { |f| require f }
Dir["./spec/system/*/shared_context.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.after(:each, type: :feature) do |example|
    next unless example.exception

    puts "\n#{'-' * 80}\n"
    puts "\n--- Smoke Test Failure Summary ---"
    puts example.full_description
    puts "Error: #{example.exception.message}"
    puts "Current path: #{begin
      Capybara.current_path
    rescue StandardError
      'unknown'
    end}"
    puts "Page title: #{begin
      page.title
    rescue StandardError
      'unknown'
    end}"
    puts "URL: #{begin
      page.current_url
    rescue StandardError
      'unknown'
    end}"
    puts "Time: #{Time.now.utc}"

    visible_text = page.text.to_s.split("\n").map(&:strip).reject(&:empty?).first(20).join("\n")
    if visible_text.nil? || visible_text.strip.empty?
      puts "Visible text (first 20 lines): [No visible text captured]"
    else
      puts "Visible text (first 20 lines):\n#{visible_text}"
    end

    puts "--- End of Summary ---\n\n"
    puts "#{'-' * 80}\n\n"
  end
end

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.include Capybara::DSL
  config.include AuthenticationHelper
  config.include RemoveUserHelper
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium_headless
end

Capybara.app_host = "http://admin.#{ENV['SUBDOMAIN']}.service.gov.uk"
