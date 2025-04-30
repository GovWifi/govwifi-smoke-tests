require "logger"
module RemoveUserHelper
  def remove_user(user:)
    logout
    login(username: ENV["GW_SUPER_ADMIN_USER"], password: ENV["GW_SUPER_ADMIN_PASS"], secret: ENV["GW_SUPER_ADMIN_2FA_SECRET"])
    click_link("User Details")
    fill_in "Username, email address or phone number", with: user
    click_button "Find user details"
    if has_link?("Remove user")
      click_link "Remove user"
      click_button "Remove user"
    end
  end
end
