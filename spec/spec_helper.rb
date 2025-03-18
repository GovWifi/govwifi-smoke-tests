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
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium_chrome_headless
end
Capybara.current_driver = :selenium_chrome_headless
Capybara.app_host = "http://admin.#{ENV['SUBDOMAIN']}.service.gov.uk"
