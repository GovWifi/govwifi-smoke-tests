require "fileutils"

RSpec.shared_context "admin", shared_context: :metadata do
  before(:all) do
    unless ENV["GW_USER"] && ENV["GW_PASS"] && ENV["GW_2FA_SECRET"] && ENV["SUBDOMAIN"]
      abort "\e[31mMust define GW_USER, GW_PASS, SUBDOMAIN and GW_2FA_SECRET\e[0m"
    end

    login(username: ENV["GW_USER"], password: ENV["GW_PASS"], secret: ENV["GW_2FA_SECRET"])

    click_button("refuse-cookies") if has_button?("refuse-cookies")
  end

  after(:each) do |example|
    # persist the session
    Capybara.current_session.instance_variable_set(:@touched, false)
  end
end
