## used to switch between different services implementations
# lib/services.rb
if !ENV['NOTIFY_BASE_URL'].to_s.empty?
  # Load the mock implementation
  require_relative 'mock_service'
  puts "🛠️ LOADING MOCK SERVICES"
else
  # Load the real production implementation
  require_relative 'prod_service'
  puts "LOADING PRODUCTION SERVICES"
end