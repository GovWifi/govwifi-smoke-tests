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
      while (result = get_first_sms(phone_number: normalised_phone_number))&.id == after_id
        print "."
        sleep interval
      end
      result.content
    end
  end

  def get_first_sms(phone_number:)
    Services.notify.get_received_texts.collection.find { |message| message.user_number == normalise(phone_number:) }
  end

  def parse_sms_message(message:)
    match = /Username:[\n\r\s]*(?<username>[a-z]{6})[\n\r\s]*Password:[\n\r\s]*(?<password>(?:[A-Z][a-z]+){3})/.match(message)
    [match[:username], match[:password]]
  end

  def normalise(phone_number:)
    phone_number.delete("+").sub(/^0/, "44")
  end
end
