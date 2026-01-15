require_relative "services"

module NotifySms
  ## This helper method sends a "GO" message to a given phone number using the specified Notify template ID.
  ## The phone number of the text message recipient. This can be a UK or international number, in E.164 format (e.g., +447700900123), must include +44 country code for UK numbers.
def send_go_message(phone_number:, template_id:)
    puts "\n" + ("-" * 40)
    puts "📨 ATTEMPTING TO SEND SMS"
    puts "   To: #{phone_number}"

    # Check exactly what the client thinks it is doing
    client = Services.notify
    puts "   Client Base URL: #{client.instance_variable_get(:@base_url)}"

    begin
      # Attempt the send
      response = client.send_sms(
        phone_number: phone_number,
        template_id: template_id
      )
      puts "✅ CLIENT SUCCESS: SMS Sent! (Message ID: #{response.id})"
    rescue => e
      # Capture ANY failure - this is likely where our problem is hiding
      puts "❌ CLIENT FAILURE: #{e.class}"
      puts "   Error Message: #{e.message}"
      puts "   Backtrace: #{e.backtrace.first}"
    end
    puts ("-" * 40) + "\n"
  end

  # This helper method reads reply SMS messages sent to a given phone number after a given message ID.
  # It polls Notify until a new message is found or the timeout is reached.
  # Throws an error if no new message is found within the timeout period.
  # param phone_number The phone number connected to the Notify service which receives SMS's.
  # param after_id The message ID to read messages after.
  # param created_after The created_at timestamp of the message with after_id, to ensure we only consider messages created after this time, supposed to be a string, but Ruby is 'helpfully' passing Time objects in some cases, ugh!!
  # param timeout The maximum time to wait for a new message, in seconds. Default is 600 seconds (10 minutes).
  # param interval The interval between polling attempts, in seconds. Default is 5 seconds.
  # return The content of the latest new message found.
  def read_reply_sms(phone_number:, after_id:, created_after:, message_type: :signup, timeout: 600, interval: 5)
    normalised_phone_number = normalise(phone_number:)
    begin
      Timeout.timeout(timeout, nil, "Waited too long for signup SMS. Last received SMS is #{after_id} at #{created_after}") do
        result = nil
        loop do
          result = get_sms_message(phone_number: normalised_phone_number, message_type: message_type)
          if result
            after_time = parse_time_object(created_after)
            message_time = parse_time_object(result.created_at)
            ## uncomment for debugging
            # puts "\tMessage ID #{result.id} created at #{message_time.iso8601} after id #{after_id} created at #{after_time.iso8601}"
            break if result.id != after_id && message_time > after_time
          end
          print "."
          sleep interval
        end
        result.content
      end
    rescue Timeout::Error
      last_message = get_latest_sms(phone_number: normalised_phone_number)
      warn "\n\tTimeout waiting for #{message_type} SMS for #{normalised_phone_number}. after_id=#{after_id}, created_after=#{created_after}, last_received_id=#{last_message&.id}, last_received_at #{last_message&.created_at}, last_received_content=#{last_message&.content&.lines&.first&.strip}"
      # Re-raise as Timeout::Error so callers/tests can rely on timeout exceptions
      raise Timeout::Error, "No signup SMS found for #{normalised_phone_number} after id #{after_id} at #{created_after}"
    end
  end

  ## Helper method to get all SMS messages.
  ## based on DRY principle the other helpers use this to get the full collection.
  ## sorts and reverses to get most recent first.
  def get_all_sms
    Services.notify.get_received_texts.collection
      .sort_by(&:created_at) ## sort by created_at ascending
      .reverse ## reverse to get descending order
  end

  ## Helper method to get the latest SMS message for a given phone number.
  def get_latest_sms(phone_number:)
    get_all_sms.find { |message| message.user_number == normalise(phone_number:) } ## find first message for the given phone number
  end

  ## Helper method to get all SMS messages for a given phone number.
  def get_all_sms_for_number(phone_number:)
    get_all_sms.select { |message| message.user_number == normalise(phone_number:) }
  end

  # This helper method is used to get the signup SMS message sent to a given phone number.
  # Find the first message that:
  # 1. Has the correct phone number.
  # 2. Contains the parsed text.
  def get_sms_message(phone_number:, message_type:)
    messages = get_all_sms_for_number(phone_number:)
    return nil unless messages ## return nil if no messages found

    messages.find do |message|
      result = !(
        ## check if it's a signup or deleted message, and call the appropriate method,
        ## if parse fails it raises StandardError which is rescued below to return nil.
        if message_type == :signup
          parse_sms_message(message: message.content).nil?
        else
          parse_deleted_message(message: message.content).nil?
        end
      )

      # If message parses correctly, return message or nil if it doesn't match
      result
    rescue StandardError
      ## uncomment for debugging
      # warn "\tMessage ID #{message&.id} did not match expected format for message_type #{message_type.inspect}, content: #{message&.content&.lines&.first&.strip}"
      nil
    end
  end

  def parse_sms_message(message:)
    match = /Username:[\n\r\s]*(?<username>[a-z]{6})[\n\r\s]*Password:[\n\r\s]*(?<password>(?:[A-Z][a-z]+){3})/.match(message)
    [match[:username], match[:password]]
  end

  ## Helper method to normalise phone numbers, removing '+' and converting leading '0' to '44'.
  ## This ensures consistent formatting for comparison.
  def normalise(phone_number:)
    phone_number.delete("+").sub(/^0/, "44")
  end

  def parse_deleted_message(message:)
    # The exact deletion message you are looking for
    deleted_message = "Your GovWifi username and password has been removed"
    # We look for an exact match, but you might need .include? if other text is present
    if message.strip.include?(deleted_message)
      message
    else
      # uncomment for debugging
      # warn "(NotifySms) Message ID #{message.id} does not contain the deleted account content: #{message&.content&.lines&.first&.strip}"
      raise StandardError
    end
  end

  ## Helper method to parse the created after parameter into a Time object.
  ## Handles different input types: String, Time, or nil.
  def parse_time_object(created_at)
    case created_at
    when String
      # Case 1: Input is the expected String format (e.g., from the API response)
      Time.parse(created_at)
    when Time
      # Case 2: Input is an unexpected Time object (Ruby 'helpfully' passing Time objects in some cases)
      created_at
    when nil
      # Case 3: Input is nil (first run with no prior SMS) Set to the Unix Epoch (Time.at(0)) for comparison
      Time.at(0)
    else
      # Safety: Handle totally unexpected types
      raise ArgumentError, "Unexpected type for created_at: #{created_at.class}"
    end
  end
end
