#!/usr/bin/env ruby

# Demo script to show cache status functionality
# Run with: ruby demo_cache_status.rb

require_relative 'config/environment'

puts '🌤️ Weather Service Cache Status Demo'
puts '=' * 50

# Clear cache to start fresh
Rails.cache.clear
puts '✅ Cache cleared'

weather_service = WeatherService.new
postal_code = 'N1E0K7'

puts "\n📍 Testing postal code: #{postal_code}"

# First request - should be fresh API data
puts "\n🔄 First request (should be fresh API data):"
begin
  result = weather_service.get_weather(postal_code)
  puts "   Data Source: #{result[:from_cache] ? '📦 Cached' : '🔄 Fresh API'}"
  puts "   Temperature: #{result[:data]['temp_c']}°C"
  puts "   Last Updated: #{result[:data]['last_updated']}"
rescue StandardError => e
  puts "   ❌ Error: #{e.message}"
end

# Second request - should be cached data
puts "\n📦 Second request (should be cached data):"
begin
  result = weather_service.get_weather(postal_code)
  puts "   Data Source: #{result[:from_cache] ? '📦 Cached' : '🔄 Fresh API'}"
  puts "   Temperature: #{result[:data]['temp_c']}°C"
  puts "   Last Updated: #{result[:data]['last_updated']}"
rescue StandardError => e
  puts "   ❌ Error: #{e.message}"
end

# Check if data is cached
puts "\n🔍 Cache status check:"
puts "   Is cached? #{weather_service.cached?(postal_code)}"

# Clear cache and check again
puts "\n🗑️ Clearing cache..."
weather_service.clear_cache(postal_code)
puts "   Is cached? #{weather_service.cached?(postal_code)}"

puts "\n✅ Demo completed!"
