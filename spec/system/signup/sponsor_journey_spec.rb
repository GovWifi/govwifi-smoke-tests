require_relative "../../../lib/notify_email"
require_relative "../../../lib/notify_sms"
require_relative "../../../lib/services"

feature "Sponsor Journey" do
  include NotifyEmail
  include NotifySms

  before :context do
    @signup_address = "sponsor@#{ENV['SUBDOMAIN']}.service.gov.uk"
    @notify_address = "#{ENV['NOTIFY_FIELD']}@notifications.service.gov.uk"
    @sponsored_email_address = from_address.sub "@", "+sponsored@"
    @sponsor_email_address = from_address
    @sponsored_sms_number = ENV["SMOKETEST_PHONE_NUMBER"]
    @govwifi_sms_number = ENV["GOVWIFI_PHONE_NUMBER"]
    @body =
      <<~BODY
        Could I please sign up the following users to GovWifi?
              #{@sponsored_email_address}
        And
              #{@sponsored_sms_number}
        Thanks
      BODY

    remove_user(user: @sponsored_sms_number)
    remove_user(user: @sponsored_email_address)

    @sponsored_query = "from:#{@notify_address} subject:Welcome is:unread to:#{@sponsored_email_address}"
    @sponsor_query = "from:#{@notify_address} subject:\"accounts have been created for your guests\" is:unread to:#{@sponsor_email_address}"
    set_all_messages_to_read(query: @sponsored_query)
    set_all_messages_to_read(query: @sponsor_query)
  end
  describe "Validate preconditions" do
    it "has removed any smoke test users" do
      logout
      login(username: ENV["GW_SUPER_ADMIN_USER"], password: ENV["GW_SUPER_ADMIN_PASS"], secret: ENV["GW_SUPER_ADMIN_2FA_SECRET"])
      click_link("User Details")
      fill_in "Username, email address or phone number", with: @sponsored_email_address
      click_button "Find user details"
      expect(page).to have_content("Nothing found")
      fill_in "Username, email address or phone number", with: @sponsored_sms_number
      click_button "Find user details"
      expect(page).to have_content("Nothing found")
    end
    it "has set the 'read' flag on all relevant emails" do
      expect(read_email(query: @sponsored_query)).to be_nil
      expect(read_email(query: @sponsor_query)).to be_nil
    end
  end
  describe "Signing up" do
    before :context do
      first_sms_message_id = get_first_sms(phone_number: @govwifi_sms_number)&.id

      send_email(from_address:, to_address: @signup_address, body: @body)

      @email_message = fetch_reply(query: @sponsored_query)
      @sponsor_email_message = fetch_reply(query: @sponsor_query)
      @sms_message = read_reply_sms(phone_number: @govwifi_sms_number, after_id: first_sms_message_id)

      @sms_username, @sms_password = parse_sms_message(message: @sms_message)
      @email_username, @email_password = parse_email_message(message: @email_message)
    end
    it "sets the sms username and password" do
      expect(@sms_username).to_not be_nil
      expect(@sms_password).to_not be_nil
    end
    it "sets the email username and password" do
      expect(@email_username).to_not be_nil
      expect(@email_password).to_not be_nil
    end
    it "includes the all sponsored users in the receipt email" do
      expect(@sponsor_email_message.payload.parts.first.body.data).to include(@sponsored_email_address)
      expect(@sponsor_email_message.payload.parts.first.body.data).to include(normalise(phone_number: @sponsored_sms_number))
    end
    describe "connect to FreeRadius" do
      let(:radius_ips) { [ENV["RADIUS_IPS"].split(",").first] }
      let(:secret) { ENV["RADIUS_KEY"] }
      let(:eapol_test) { GovwifiEapoltest.new(radius_ips:, secret:) }

      it "can successfully connect to Radius using the credentials in the email" do
        output = eapol_test.run_peap_mschapv2(username: @email_username,
                                              password: @email_password)
        expect(output).to all have_been_successful
      end
      it "can successfully connect to Radius using the credentials in the sms" do
        output = eapol_test.run_peap_mschapv2(username: @sms_username,
                                              password: @sms_password)
        expect(output).to all(have_been_successful), output.join("\n")
      end
    end
  end
end
