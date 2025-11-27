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
    let (:old_message) { double(id: "old_id", user_number: phone_number, created_at: "2024-01-01T12:00:00Z", content: "Username:\nzyxwv\nPassword:\nCarLorryBus") }
    let (:new_message) { double(id: "new_id", user_number: phone_number, created_at: "2024-01-01T13:00:00Z", content: "Username:\nabcdef\nPassword:\nDogCatFox") }

    it "returns the first new message even if it is the first one" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: []),
                                                                      double(collection: [new_message]))
      allow(self).to receive(:get_signup_sms).and_return(nil, new_message)
      expect(read_reply_sms(phone_number:, after_id: nil, after_created_at: nil, timeout: 2, interval: 0)).to eq "Username:\nabcdef\nPassword:\nDogCatFox"
    end

    it "returns the first new message" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: [old_message]),
                                                                      double(collection: [new_message, old_message]))
      allow(self).to receive(:get_signup_sms).and_return(nil, new_message)
      expect(read_reply_sms(phone_number:, after_id: "old_id", after_created_at: "2024-01-01T12:00:00Z", timeout: 2, interval: 0)).to eq "Username:\nabcdef\nPassword:\nDogCatFox"
    end
    it "times out" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: [old_message]))
      expect { read_reply_sms(phone_number:, after_id: "old_id", after_created_at: "2024-01-01T12:00:00Z",timeout: 2, interval: 0) }.to raise_error(Timeout::Error)
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


  describe "#get_first_sms" do
    let(:message1) { double(id: "id1", user_number: "07701111111", content: "body1") }
    let(:message2) { double(id: "id2", user_number: phone_number, content: "body2") }

    it "Ignores messages from other phone numbers" do
      allow(notify_client).to receive(:get_received_texts).and_return(double(collection: [message1, message2]))
      expect(get_first_sms(phone_number:).id).to eq("id2")
    end
  end

  describe "#parse_message" do
    it "parses the message" do
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
end
