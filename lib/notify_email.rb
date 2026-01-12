require_relative "../lib/services"
require 'net/http'
require 'json'
require 'ostruct'
require 'uri'

module NotifyEmail
  def parse_email_message(message:)
    data = message.payload.parts.first.body.data
    match = /Your username:[\n\r\s]*(?<username>[a-z]{6})[\n\r\s]*Your password:[\n\r\s]*(?<password>(?:[A-Z][a-z]+){3})/.match(data)
    [match[:username], match[:password]]
  end

  def send_email(to_address:, from_address:, subject: "", body: "")
    # We still send via Gmail so the real GovWifi application receives the trigger.
    message = Google::Apis::GmailV1::Message.new
    message.raw = [
      "From: #{from_address}",
      "To: #{to_address}",
      "Subject: #{subject}",
      "",
      body,
    ].join("\n")
    Services.gmail.send_user_message("me", message)
  end

  def from_address
    Services.gmail.get_user_profile("me").email_address
  end

  def read_email(query: "")
    if ENV["USE_NOTIFY_PIT"] == "true"
      read_email_from_pit(query)
    else
      messages = Services.gmail.list_user_messages("me", q: query).messages
      return if messages.nil?
      Services.gmail.get_user_message("me", messages[0].id)
    end
  end

  # Custom method to fetch emails from the Mock Service
  def read_email_from_pit(query)
    # Extract the 'to' address from the Gmail query string
    match = query.match(/to:(\S+)/)
    to_address = match ? match[1] : nil
    return nil unless to_address

    uri = URI("#{Services.notify_pit_url}/pit/notifications")
    response = Net::HTTP.get_response(uri)
    data = JSON.parse(response.body)

    # Find the latest email sent to this address
    notification = data.select { |n| n["type"] == "email" && n["email_address"] == to_address }.last
    return nil unless notification

    # Construct a response object that mimics the Google Gmail Message structure
    OpenStruct.new(
      id: notification["id"],
      payload: OpenStruct.new(
        parts: [
          OpenStruct.new(
            body: OpenStruct.new(
              data: reconstruct_email_body(notification)
            )
          )
        ]
      )
    )
  end

  def reconstruct_email_body(notification)
    p = notification["personalisation"] || {}
    "Your username:\n#{p['username']}\nYour password:\n#{p['password']}"
  end

  def fetch_reply(query:, timeout: 300)
    Timeout.timeout(timeout, nil, "Waited too long for signup email") do
      while (message = read_email(query:)).nil?
        print "."
        sleep 2
      end
      message
    end
  end

  def set_all_messages_to_read(query:)
    # No-op for mock service
    return if ENV["USE_NOTIFY_PIT"] == "true"

    messages = Services.gmail.list_user_messages("me", q: query).messages || []
    messages.each do |message|
      Services.gmail.modify_message("me",
                                    message.id,
                                    Google::Apis::GmailV1::ModifyMessageRequest.new(remove_label_ids: %w[UNREAD]))
    end
  end
end