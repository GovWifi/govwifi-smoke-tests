require "notify_sms"
require "services"
require "securerandom"

describe NotifySms do
  include NotifySms

  let(:phone_number) { "447700900000" }
  let(:notify_client) { instance_double(Notifications::Client) }

  before :each do
    allow(Services).to receive(:notify).and_return(notify_client)
  end

  describe "#send_go_message" do
    it "sends a go message to the phone number" do
      allow(notify_client).to receive(:send_sms)
      send_go_message(phone_number:, template_id: "notify_template_id")
      expect(notify_client).to have_received(:send_sms).with(phone_number:, template_id: "notify_template_id")
    end
  end

  describe "#read_reply_sms" do
    let (:old_message) { double(id: "old_id", user_number: phone_number, created_at: "2025-11-27 13:52:33 UTC", content: "Username:\nzyxwv\nPassword:\nCarLorryBus") }
    let (:new_message) { double(id: "new_id", user_number: phone_number, created_at: "2025-11-27 14:52:33 UTC", content: "Username:\nabcdef\nPassword:\nDogCatFox") }

    it "returns the latest new message even if it is the first one" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: []),
                                                                      double(collection: [new_message]))
      allow(self).to receive(:get_signup_sms).and_return(nil, new_message)
      expect(read_reply_sms(phone_number:, after_id: nil, after_created_at: nil, timeout: 2, interval: 0)).to eq "Username:\nabcdef\nPassword:\nDogCatFox"
    end

    it "returns the first new message" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: [old_message]),
                                                                      double(collection: [new_message, old_message]))
      allow(self).to receive(:get_signup_sms).and_return(nil, new_message)
      expect(read_reply_sms(phone_number:, after_id: "old_id", after_created_at: "2025-11-27 13:52:33 UTC", timeout: 2, interval: 0)).to eq "Username:\nabcdef\nPassword:\nDogCatFox"
    end
    it "times out" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: [old_message]))
      expect { read_reply_sms(phone_number:, after_id: "old_id", after_created_at: "2025-11-27 13:52:33 UTC",timeout: 2, interval: 0) }.to raise_error(Timeout::Error)
    end
  end

  describe "When calling the get reply sms method with a time object when Ruby auto converts the string to time." do
    before :each do
      new_message = double(id: "new_id", user_number: phone_number, created_at: "2025-11-27 14:52:33 UTC",
                     content: "Username:\nabcdef\nPassword:\nDogCatFox")
      old_message = double(id: "old_id", user_number: phone_number, created_at: "2025-11-27 13:52:33 UTC",
                     content: "Username:\nzyxwv\nPassword:\nCarLorryBus")
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: []),
                                                                      double(collection: [new_message]))
      allow(self).to receive(:get_signup_sms).and_return(nil, new_message)
    end
    it "Should expect a message with default time set to 1970 is no created date found." do
      expect(read_reply_sms(phone_number:, after_id: "old_id", after_created_at: Time.parse("2025-11-27 14:00:33 UTC"), timeout: 2, interval: 0)).to eq "Username:\nabcdef\nPassword:\nDogCatFox"
    end
  end

  describe "normalise phone numbers" do
    before :each do
      new_message = double(id: "new_id", user_number: phone_number, created_at: "2024-01-01T13:00:00Z",
                     content: "Username:\nabcdef\nPassword:\nDogCatFox")
      old_message = double(id: "old_id", user_number: phone_number,created_at: "2024-01-01T12:00:00Z",
                     content: "Username:\nzyxwv\nPassword:\nCarLorryBus")
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: [old_message]),
                                                                      double(collection: [new_message, old_message]))
      allow(self).to receive(:get_signup_sms).and_return(nil, new_message)
    end
    it "removes the + from the phone number" do
      expect(read_reply_sms(phone_number: "+#{phone_number}", after_id: "old_id", after_created_at: "2024-01-01T12:00:00Z", timeout: 2, interval: 0)).to eq "Username:\nabcdef\nPassword:\nDogCatFox"
    end
    it "replaces '0' with '44' if the phone number is not international" do
      expect(read_reply_sms(phone_number: "07700900000", after_id: "old_id", after_created_at: "2024-01-01T12:00:00Z", timeout: 2, interval: 0)).to eq "Username:\nabcdef\nPassword:\nDogCatFox"
    end
  end

  describe "When get_latest_sms is called" do
    let(:message1) { double(id: "id1", user_number: "07701111111", content: "body1") }
    let(:message2) { double(id: "id2", user_number: phone_number, content: "body2") }

    it "should Ignores messages from other phone numbers" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: [message1, message2]))
      expect(get_latest_sms(phone_number:).id).to eq("id2")
    end
  end

  describe "when parse_message is called " do
    it "should parses the message and return the user and password" do
      message = <<~HTML
        Windows, Apple, and Chromebook users:
        Username:
        abcdef
        Password:
        DogCatFox
        Your password is case-sensitive with no spaces between words.

        Go to your wifi settings, select 'GovWifi' and enter your details.
      HTML
      expect(parse_sms_message(message:)).to eq %w[abcdef DogCatFox]
    end
  end

  describe "When calling the read reply sms method" do
    let(:deleted_message_content) { "Your account has been removed from GovWifi. Your account has been removed from GovWifi. If you need to sign up again, text 'Go' to 07537 417 417." }
    let(:deleted_message) {double(:message, id: "new_deleted_id",content: deleted_message_content, created_at: "2025-11-27 14:02:33 UTC" )}

    # The old message must still be defined for the collection stub
    let(:old_message_deleted_flow) {double(:message,id: "old_id", content: "some other content", created_at: "2025-11-27 13:52:33 UTC" )}

    it "should return the first new deleted message" do
      # 1. Stub the low-level API call (get_received_texts) to return the old message first, then the new one.
      allow(notify_client).to receive(:get_received_texts).and_return(
        double(collection: [old_message_deleted_flow]),
        double(collection: [deleted_message, old_message_deleted_flow])
      )

      # 2. Stub the high-level retrieval method (get_deleted_sms) to return nil first (no match), then the new message.
      # This simulates the new message arriving and matching the content filter.
      allow(self).to receive(:get_deleted_sms).and_return(nil, deleted_message)

      # 3. Call read_reply_sms, specifying message_type: :delete and checking the expected content.
      expect(read_reply_sms(phone_number: phone_number, after_id: "old_id", after_created_at: "2025-11-27 13:52:33 UTC",  message_type: :deleted,timeout: 2, interval: 0)).to eq deleted_message_content
    end
  end

  describe "#get_deleted_sms" do
    let(:phone_number) { "07700900000" }
    let(:normalised_phone) { "447700900000" } # Assuming normalise() works

    # The exact message content the method checks for
    let(:deleted_message_content) { "Your account has been removed from GovWifi." }

    # A mock message object containing the correct content
    let(:deleted_message_object) {double(:message,id: "deleted_id_123",content: deleted_message_content, user_number: normalised_phone, created_at: Time.now.iso8601 )}
    # A mock message object containing incorrect content
    let(:incorrect_message_object) {double(:message, id: "wrong_id_456", content: "Your GovWifi account has been removed.", user_number: normalised_phone, created_at: Time.now.iso8601 )}

    it "returns the message object when content matches the deleted message exactly" do
      # Stub the prerequisite method to return the correct message
      allow(self).to receive(:get_latest_sms).and_return(deleted_message_object)

      result = get_deleted_sms(phone_number: phone_number)

      # The result should be the actual message object
      expect(result).to eq deleted_message_object
      expect(result.content).to eq deleted_message_content
    end

    it "returns nil when the content does not match the deleted message" do
      # Stub the prerequisite method to return a message with incorrect content
      allow(self).to receive(:get_latest_sms).and_return(incorrect_message_object)

      result = get_deleted_sms(phone_number: phone_number)

      # The result should be nil because the content check failed
      expect(result).to be_nil
    end

    it "returns nil when no messages are available" do
      # Stub the prerequisite method to return nil (no messages found)
      allow(self).to receive(:get_latest_sms).and_return(nil)

      result = get_deleted_sms(phone_number: phone_number)

      # The result should be nil because there was no message to check
      expect(result).to be_nil
    end
  end
end
