require_relative "../../../lib/notify_email"
require_relative "../../../lib/services"

feature "Email Journey" do
  include NotifyEmail

  let(:signup_address) { "signup@#{ENV['SUBDOMAIN']}.service.gov.uk" }
  let(:notify_address) do
    "#{ENV['NOTIFY_FIELD']}@notifications.service.gov.uk"
  end

  before :all do
    remove_user(user: from_address)
  end
  it "has removed the user" do
    login(username: ENV["GW_SUPER_ADMIN_USER"], password: ENV["GW_SUPER_ADMIN_PASS"], secret: ENV["GW_SUPER_ADMIN_2FA_SECRET"])
    click_link("User Details")
    fill_in "Username, email address or phone number", with: from_address
    click_button "Find user details"
    expect(page).to have_content("Nothing found")
  end
  it "signs up successfully" do
    query = "from:#{notify_address} subject:Welcome is:unread to:#{from_address}"

    set_all_messages_to_read(query:)
    send_email(from_address:, to_address: signup_address, body: "go")
    message = fetch_reply(query:)

    username, password = parse_email_message(message:)
    expect(username).to_not be_nil
    expect(password).to_not be_nil

    eapol_test = GovwifiEapoltest.new(radius_ips: ENV["RADIUS_IPS"].split(","),
                                      secret: ENV["RADIUS_KEY"])

    output = eapol_test.run_peap_mschapv2(username:,
                                          password:)

    expect(output).to all(have_been_successful), output.join("\n")
  end
end
