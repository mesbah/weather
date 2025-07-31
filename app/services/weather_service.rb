require 'net/http'
require 'json'
require 'uri'

class WeatherService
  API_BASE_URL = 'https://api.weatherapi.com/v1/forecast.json'
  # API key is now loaded from environment variable
  API_KEY = ENV['WEATHER_API_KEY']
  CACHE_DURATION = 30.minutes

  def get_weather(postal_code)
    # Normalize postal code (remove spaces, convert to uppercase)
    normalized_postal_code = normalize_postal_code(postal_code)

    # Try to get from cache first
    cached_data = Rails.cache.read(cache_key(normalized_postal_code))
    if cached_data
      return {
        data: cached_data,
        from_cache: true
      }
    end

    # If not cached, fetch from API
    weather_data = fetch_weather_from_api(normalized_postal_code)

    # Filter the response to keep only the required fields
    filtered_data = filter_weather_data(weather_data)

    # Cache the filtered response for 30 minutes
    Rails.cache.write(
      cache_key(normalized_postal_code),
      filtered_data,
      expires_in: CACHE_DURATION
    )

    {
      data: filtered_data,
      from_cache: false
    }
  end

  def filter_weather_data(weather_data)
    return {} unless weather_data && weather_data['current']

    current = weather_data['current']
    forcast = weather_data['forecast']['forecastday'][0]['day']

    {
      'last_updated' => current['last_updated'],
      'last_updated_epoch' => current['last_updated_epoch'],
      'temp_c' => current['temp_c'],
      'temp_f' => current['temp_f'],
      'maxtemp_c' => forcast['maxtemp_c'],
      'maxtemp_f' => forcast['maxtemp_f'],
      'mintemp_c' => forcast['mintemp_c'],
      'mintemp_f' => forcast['mintemp_f'],
      'feelslike_c' => current['feelslike_c'],
      'feelslike_f' => current['feelslike_f'],
      'windchill_c' => current['windchill_c'],
      'windchill_f' => current['windchill_f']
    }
  end

  def normalize_postal_code(postal_code)
    postal_code.to_s.strip.upcase.gsub(/[^A-Z0-9]/, '')
  end

  # Method to clear cache for a specific postal code
  def clear_cache(postal_code = nil)
    if postal_code
      normalized_postal_code = normalize_postal_code(postal_code)
      Rails.cache.delete(cache_key(normalized_postal_code))
    else
      # Clear all weather cache keys (if you have a way to iterate through cache keys)
      Rails.cache.clear
    end
  end

  # Method to check if data is cached for a postal code
  def cached?(postal_code)
    normalized_postal_code = normalize_postal_code(postal_code)
    Rails.cache.exist?(cache_key(normalized_postal_code))
  end

  # Method to get cache expiry time for a postal code
  def cache_expiry(postal_code)
    normalized_postal_code = normalize_postal_code(postal_code)
    Rails.cache.redis&.ttl(cache_key(normalized_postal_code)) if Rails.cache.respond_to?(:redis)
  end

  private

  def cache_key(postal_code)
    "weather_service:#{postal_code}"
  end

  def fetch_weather_from_api(postal_code)
    uri = build_api_uri(postal_code)

    begin
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        # Parse error response to get specific error code
        error_data = parse_error_response(response)
        error_code = error_data['error']&.dig('code')

        # Check for specific API quota and access errors
        if response.code == '403' && error_code
          case error_code
          when 2007
            alert_team_quota_exceeded(postal_code, error_data)
            raise 'API key has exceeded calls per month quota'
          when 2008
            alert_team_api_disabled(postal_code, error_data)
            raise 'API key has been disabled'
          when 2009
            alert_team_access_denied(postal_code, error_data)
            raise 'API key does not have access to the resource'
          else
            Rails.logger.error "Weather API request failed for postal code #{postal_code}: " \
                               "#{response.code} - #{response.message}"
            raise "API request failed with status: #{response.code} - #{response.message}"
          end
        else
          Rails.logger.error "Weather API request failed for postal code #{postal_code}: " \
                             "#{response.code} - #{response.message}"
          raise "API request failed with status: #{response.code} - #{response.message}"
        end
      end
    rescue StandardError => e
      Rails.logger.error "Weather API error for postal code #{postal_code}: #{e.message}"
      raise "Failed to fetch weather data: #{e.message}"
    end
  end

  def parse_error_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    { 'error' => { 'message' => response.message, 'code' => nil } }
  end

  def alert_team_quota_exceeded(postal_code, error_data)
    message = "🚨 WEATHER API QUOTA EXCEEDED 🚨\n" \
              "Postal Code: #{postal_code}\n" \
              "Error Code: 2007\n" \
              "Message: API key has exceeded calls per month quota\n" \
              "Time: #{Time.current}\n" \
              "Error Details: #{error_data['error']}"

    Rails.logger.error message
    # Datatdog monitor, or error tracking system
  end

  def alert_team_api_disabled(postal_code, error_data)
    message = "🚨 WEATHER API KEY DISABLED 🚨\n" \
              "Postal Code: #{postal_code}\n" \
              "Error Code: 2008\n" \
              "Message: API key has been disabled\n" \
              "Time: #{Time.current}\n" \
              "Error Details: #{error_data['error']}"

    Rails.logger.error message
    # Datatdog monitor, or error tracking system
  end

  def alert_team_access_denied(postal_code, error_data)
    message = "🚨 WEATHER API ACCESS DENIED 🚨\n" \
              "Postal Code: #{postal_code}\n" \
              "Error Code: 2009\n" \
              "Message: API key does not have access to the resource\n" \
              "Time: #{Time.current}\n" \
              "Error Details: #{error_data['error']}"

    Rails.logger.error message
    # Datatdog monitor, or error tracking system
  end

  def build_api_uri(postal_code)
    uri = URI(API_BASE_URL)
    params = {
      # API key is now loaded from environment variable
      key: API_KEY,
      q: postal_code,
      days: 1,
      aqi: 'no',
      alerts: 'no'
    }
    uri.query = URI.encode_www_form(params)
    uri
  end
end
