require_relative "../lib/services"
require 'time' ## not sure I need this, but Time.parse gives error without it in some contexts

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
  # param phone_number The phone number to read messages for.
  # param after_id The message ID to read messages after.
  # param after_created_at The created_at timestamp of the message with after_id, to ensure we only consider messages created after this time, supposed to be a string, but Ruby is 'helpfully' passing Time objects in some cases, ugh!!
  # param timeout The maximum time to wait for a new message, in seconds. Default is 600 seconds (10 minutes).
  # param interval The interval between polling attempts, in seconds. Default is 5 seconds.
  # return The content of the first new message found.
  def read_reply_sms(phone_number:, after_id:, after_created_at:, message_type: :signup, timeout: 600, interval: 5)
    normalised_phone_number = normalise(phone_number:)
    puts "(NotifySms) Waiting for SMS message for #{normalised_phone_number} after id #{after_id} created at #{after_created_at}"
    after_time = parse_time_object(after_created_at)
    puts "(NotifySms) after_time parsed as #{after_time}"
    begin
      Timeout.timeout(timeout, nil, "Waited too long for signup SMS. Last received SMS is #{after_id}") do
        result = nil
        loop do
          ## check if it's a signup or deleted message, and call the appropriate method.
          result = message_type == :signup ? get_signup_sms(phone_number: normalised_phone_number) : get_deleted_sms(phone_number: normalised_phone_number)
          if result
            message_time = parse_time_object(result.created_at)
            break if result.id != after_id && message_time > after_time
          end

          print "."
          sleep interval
        end
        result.content
      end
    rescue Timeout::Error
      last_message = get_latest_sms(phone_number: normalised_phone_number)
      warn "Timeout waiting for signup SMS for #{normalised_phone_number}. after_id=#{after_id}, last_received_id=#{last_message&.id}, last_received_content=#{last_message&.content.inspect}"
      # Re-raise as Timeout::Error so callers/tests can rely on timeout exceptions
      raise Timeout::Error, "No signup SMS found for #{normalised_phone_number} after id #{after_id}"
    end
  end

  def get_latest_sms(phone_number:)
    Services.notify.get_received_texts.collection.find { |message| message.user_number == normalise(phone_number:) }
  end

  # This helper method is used to get the signup SMS message sent to a given phone number.
  # Find the first message that:
  # 1. Has the correct phone number.
  # 2. Contains the parsed text.
  def get_signup_sms(phone_number:)
    message = get_latest_sms(phone_number:)
    return nil unless message
    begin
      # parse_sms_message raises when it doesn't match; rescue and treat as non-match
      puts "(NotifySms) Checking message ID #{message&.id} for signup content"
      !parse_sms_message(message: message.content).nil?
      # If message parses correctly, return message or nil if it doesn't match
      return !parse_sms_message(message: message.content).nil? ? message : nil
    rescue StandardError
      return nil
    end
  end

  def parse_sms_message(message:)
    match = /Username:[\n\r\s]*(?<username>[a-z]{6})[\n\r\s]*Password:[\n\r\s]*(?<password>(?:[A-Z][a-z]+){3})/.match(message)
    [match[:username], match[:password]]
  end

  def normalise(phone_number:)
    phone_number.delete("+").sub(/^0/, "44")
  end

  def get_deleted_sms(phone_number:)
    message = get_latest_sms(phone_number:)

    # Return nil immediately if no message was found
    return nil unless message

    # The exact deletion message you are looking for
    deleted_message = "Your account has been removed from GovWifi."

    # We look for an exact match, but you might need .include? if other text is present
    if message.content.strip.include?(deleted_message)
      puts "(NotifySms) Found deleted account message ID #{message.id}."
      return message
    else
      puts "(NotifySms) Message ID #{message.id} does not contain the deleted account content."
      return nil
    end
  end

  ## Helper method to parse the after_created_at parameter into a Time object.
  ## Handles different input types: String, Time, or nil.
  def parse_time_object(after_created_at)
    case after_created_at
    when String
      # Case 1: Input is the expected String format (e.g., from the API response)
      puts "(NotifySms) after_created_at was type string: #{after_created_at}"
      return Time.parse(after_created_at)
    when Time
      # Case 2: Input is an unexpected Time object (Ruby 'helpfully' passing Time objects in some cases)
      puts "(NotifySms) after_created_at was Time object: #{after_created_at.iso8601}"
      return after_created_at
    when nil
      # Case 3: Input is nil (first run with no prior SMS) Set to the Unix Epoch (Time.at(0)) for comparison
      puts "(NotifySms) after_created_at is nil, setting to Epoch time"
      return Time.at(0)
    else
      # Safety: Handle totally unexpected types
      raise ArgumentError, "Unexpected type for after_created_at: #{after_created_at.class}"
    end

  end
end
