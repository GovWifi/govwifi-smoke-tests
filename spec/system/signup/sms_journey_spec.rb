require "notifications/client"
require_relative "../../../lib/notify_sms"

feature "SMS Journey" do
  include NotifySms

  before :context do
    @govwifi_notify_sms_number = ENV["GOVWIFI_PHONE_NUMBER"]
    @smoketest_user_sms_number = ENV["SMOKETEST_PHONE_NUMBER"]
    ## Ensure any existing users are removed before starting the test
    @user_was_removed = remove_user(user: @smoketest_user_sms_number)
    sleep 5 ## ensure messages have different timestamps
  end
  describe "Validate preconditions" do
    it "should receive user removed sms" do
      unless @user_was_removed
        # If the user wasn't found/removed, we skip this part of the test.
        # This is ideal if the test assumes a clean slate.
        skip "User '#{@smoketest_user_sms_number}' were not found for removal. Skipping removal SMS check."
      end
      sms_deleted_message = read_reply_sms(phone_number: @govwifi_notify_sms_number, after_id: nil, created_after: nil, message_type: :deleted)
      expect(sms_deleted_message).to include("Your GovWifi username and password has been removed.")
    end
  end
  describe "Signing up" do
    before :context do
      latest_sms_message = get_latest_sms(phone_number: @govwifi_notify_sms_number)
      id = latest_sms_message&.id
      created_at = latest_sms_message&.created_at

      send_go_message(phone_number: @govwifi_notify_sms_number, template_id: ENV["NOTIFY_GO_TEMPLATE_ID"])
      sleep 5 ## ensure messages have different timestamps

      @sms_message = read_reply_sms(phone_number: @govwifi_notify_sms_number, after_id: id, created_after: created_at)
      @sms_username, @sms_password = parse_sms_message(message: @sms_message)
    end

    it "sets the sms username and password" do
      expect(@sms_username).to_not be_nil
      expect(@sms_password).to_not be_nil
    end
    describe "connect to FreeRadius" do
      let(:radius_ips) { [ENV["RADIUS_IPS"].split(",").first] }
      let(:secret) { ENV["RADIUS_KEY"] }
      let(:eapol_test) { GovwifiEapoltest.new(radius_ips:, secret:) }

      it "can successfully connect to Radius using the credentials in the sms" do
        puts "\t(SMS) Run EAPOL test with SMS Username: #{@sms_username}"
        output = eapol_test.run_peap_mschapv2(username: @sms_username, password: @sms_password)
        expect(output).to all(have_been_successful), output.join("\n")
      end
    end
  end
end
