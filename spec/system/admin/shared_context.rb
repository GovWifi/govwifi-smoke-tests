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

    if example.exception
      begin
        warn("\e[31mExample failed: #{example.full_description}\e[0m")

        # URL and title
        begin
          warn("Current URL: #{page.current_url}")
        rescue StandardError
          warn("Current URL: <unavailable>")
        end

        begin
          warn("Page title: #{page.title}")
        rescue StandardError
          warn("Page title: <unavailable>")
        end

        # Full page HTML (may be large — CodeBuild logs will retain it)
        begin
          warn("---- PAGE HTML START ----")
          warn(page.html)
          warn("---- PAGE HTML END ----")
        rescue StandardError => e
          warn("Could not capture page HTML: #{e.message}")
        end

        # Browser console logs (Selenium)
        begin
          if Capybara.current_session.driver.browser.respond_to?(:manage) &&
              Capybara.current_session.driver.browser.manage.respond_to?(:logs)
            logs = Capybara.current_session.driver.browser.manage.logs.get(:browser)
            warn("---- BROWSER CONSOLE LOGS START ----")
            logs.each { |l| warn("[#{l.level}] #{l.message}") }
            warn("---- BROWSER CONSOLE LOGS END ----")
          else
            warn("Browser console logs: <unsupported by driver>")
          end
        rescue StandardError => e
          warn("Could not capture browser console logs: #{e.message}")
        end

        # Screenshot as base64 (print to logs so CI can save it if needed)
        begin
          browser = Capybara.current_session.driver.browser
          if browser.respond_to?(:screenshot_as)
            b64 = browser.screenshot_as(:base64)
            warn("---- SCREENSHOT_BASE64 START ----")
            warn(b64)
            warn("---- SCREENSHOT_BASE64 END ----")
            warn("Copy and paste into base64 decoder to see the screenshot.")
          else
            warn("Screenshot: <unsupported by driver>")
          end
        rescue StandardError => e
          warn("Could not capture screenshot: #{e.message}")
        end
      rescue StandardError => e
        warn("\e[31mFailed to capture diagnostics: #{e.message}\e[0m")
      end

      # keep previous behaviour of dumping the page body to test output (best-effort)
      begin
        warn("\e[35m#{page.body}\e[0m")
      rescue StandardError
        # ignore
      end
    end
  end
end
