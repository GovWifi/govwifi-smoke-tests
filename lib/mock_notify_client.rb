require 'net/http'
require 'json'
require 'uri'
require 'ostruct'

class MockNotifyClient
  def initialize(base_url)
    @base_url = base_url.to_s.strip.chomp('/')
    @api_key  = "mock_key-00000000-0000-0000-0000-000000000000-11111111-1111-1111-1111-111111111111"
    puts "\n🔊 [MockClient] Initialized with Base URL: #{@base_url}"
  end

  # --- WRITE ---

  def send_sms(phone_number:, template_id:, personalisations: nil, reference: nil)
    payload = {
      phone_number: phone_number,
      template_id: template_id,
      personalisation: personalisations,
      reference: reference
    }.compact
    puts "\n➡️ [MockClient] SEND SMS"
    puts "   To: #{phone_number}"
    _post("/v2/notifications/sms", payload)
  end

  # --- READ ---

  # Mocks: client.get_received_texts
  def get_received_texts(created_at: nil)
    puts "\n⬅️ [MockClient] CHECK INBOX (get_received_texts)"
    # 1. Fetch from Mock API
    data = _get("/v2/received-text-messages")

    # 2. Extract the list (NotifyPit returns { "received_text_messages": [...] })
    # If the key is missing, default to empty array
    list = data["received_text_messages"] || []

    # 3. Wrap in OpenStruct to mimic the Gem's response object
    # The real gem returns an object where .collection is the array
    collection = list.map { |item| OpenStruct.new(item) }
    OpenStruct.new(collection: collection)
  end

  # Mocks: client.get_notifications
  # (Your read_reply_sms likely uses this to find the password sent to the user)
  def get_notifications(template_type: nil, status: nil, reference: nil, older_than: nil)
    puts "\n⬅️ [MockClient] CHECK OUTBOX (get_notifications)"
    data = _get("/v2/notifications")

    list = data["notifications"] || []

    collection = list.map { |item| OpenStruct.new(item) }
    OpenStruct.new(collection: collection)
  end

  private

  # --- HELPERS ---

  def _post(path, payload)
    uri = URI("#{@base_url}#{path}")
    response = Net::HTTP.post(
      uri,
      payload.to_json,
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key}"
    )
    puts "   Response: #{response.code} #{response.message}"
    _handle_response(response)
  end

  def _get(path)
    puts "   GET URL:  #{uri}"
    uri = URI("#{@base_url}#{path}")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{@api_key}"
    req['Content-Type']  = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    puts "   Response: #{response.code} #{response.message}"

    # For GET requests, we return the raw Hash so the caller can extract the specific list key
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      # If the endpoint doesn't exist on NotifyPit yet, return empty structure to avoid crashing
      puts "   ⚠️  Empty or error response from Mock."
      {}
    end
  end

  def _handle_response(response)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, object_class: OpenStruct)
    else
      raise "Mock Client Failed: #{response.code} - #{response.body}"
    end
  end
end