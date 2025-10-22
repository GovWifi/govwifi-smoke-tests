require_relative "../lib/services"
module NotifySms
  def send_go_message(phone_number:, template_id:)
    Services.notify.send_sms(
      phone_number:,
      template_id:,
    )
  end

  def read_reply_sms(phone_number:, after_id:, timeout: 600, interval: 5)
    Timeout.timeout(timeout, nil, "Waited too long for signup SMS. Last received SMS is #{after_id}") do
      normalised_phone_number = normalise(phone_number:)
      while (result = get_signup_sms(phone_number: normalised_phone_number))&.id == after_id
        print "."
        sleep interval
      end
      result.content
    end
  end

  ## This helper method is used to get the first SMS received from a given phone number.
  ## however, it does not filter based on content.
  def get_first_sms(phone_number:)
    Services.notify.get_received_texts.collection.find { |message| message.user_number == normalise(phone_number:) }
  end

  # This helper method is used to get the signup SMS message sent to a given phone number.
  # Find the first message that:
  # 1. Has the correct phone number.
  # 2. Contains the target text.
  def get_signup_sms(phone_number:)
    target_text = "Windows, Apple, and Chromebook users:" ## first line of SMS template
    normalised_phone_number = normalise(phone_number:)

    messages = Services.notify.get_received_texts.collection
    messages.find do |message|
      message.user_number == normalised_phone_number &&
        message.content.include?(target_text)
    end
  end

  def parse_sms_message(message:)
    match = /Username:[\n\r\s]*(?<username>[a-z]{6})[\n\r\s]*Password:[\n\r\s]*(?<password>(?:[A-Z][a-z]+){3})/.match(message)
    [match[:username], match[:password]]
  end

  def normalise(phone_number:)
    phone_number.delete("+").sub(/^0/, "44")
  end
end
