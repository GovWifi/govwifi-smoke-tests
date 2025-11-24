RSpec.configure do |config|
  config.after(:each) do |example|
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
