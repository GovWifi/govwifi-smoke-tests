require "notifications/client"
require_relative "../../../lib/notify_sms"

feature "SMS Journey" do
  include NotifySms
  before :each do
    remove_user(user: ENV["SMOKETEST_PHONE_NUMBER"])
  end
  it "signs up using an SMS journey" do
    id = get_first_sms(phone_number: ENV["GOVWIFI_PHONE_NUMBER"])&.id
    send_go_message(phone_number: ENV["GOVWIFI_PHONE_NUMBER"], template_id: ENV["NOTIFY_GO_TEMPLATE_ID"])
    message = read_reply_sms(phone_number: ENV["GOVWIFI_PHONE_NUMBER"], after_id: id)
    username, password = parse_sms_message(message:)

    eapol_test = GovwifiEapoltest.new(radius_ips: ENV["RADIUS_IPS"].split(","),
                                      secret: ENV["RADIUS_KEY"])

    output = eapol_test.run_peap_mschapv2(username:,
                                          password:)
    expect(output).to all(have_been_successful), output.join("\n")
  end
end
