require_relative "../lib/services"
module NotifySms
  def send_go_message(phone_number:, template_id:)
    Services.notify.send_sms(
      phone_number:,
      template_id:,
    )
  end

  # This helper method reads reply SMS messages sent to a given phone number after a given message ID.
  # It polls Notify until a new message is found or the timeout is reached.
  # Throws an error if no new message is found within the timeout period.
  def read_reply_sms(phone_number:, after_id:, timeout: 600, interval: 5)
    normalised_phone_number = normalise(phone_number:)
    begin
      Timeout.timeout(timeout, nil, "Waited too long for signup SMS. Last received SMS is #{after_id}") do
        result = nil
        loop do
          result = get_signup_sms(phone_number: normalised_phone_number)
          break if result && result.id != after_id

          print "."
          sleep interval
        end
        result.content
      end
    rescue Timeout::Error
      last_message = get_first_sms(phone_number: normalised_phone_number)
      warn "Timeout waiting for signup SMS for #{normalised_phone_number}. after_id=#{after_id}, last_received_id=#{last_message&.id}, last_received_content=#{last_message&.content.inspect}"
      raise "No signup SMS found for #{normalised_phone_number} after id #{after_id}"
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
  # 2. Contains the parsed text.
  def get_signup_sms(phone_number:)
    normalised_phone_number = normalise(phone_number:)
    messages = Services.notify.get_received_texts.collection
    messages.find do |message|
      # ensure phone matches first
      next false unless message.user_number == normalised_phone_number

      begin
        # parse_sms_message raises when it doesn't match; rescue and treat as non-match
        !parse_sms_message(message: message.content).nil?
      rescue StandardError
        false
      end
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
