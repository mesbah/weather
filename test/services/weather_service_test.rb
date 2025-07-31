require "test_helper"

class WeatherServiceTest < ActiveSupport::TestCase
  def setup
    @weather_service = WeatherService.new
    @postal_code = "N1E0K7"
    @normalized_postal_code = "N1E0K7"
    
    # Clear any existing cache
    Rails.cache.clear
  end

  def teardown
    Rails.cache.clear
  end

  test "should initialize weather service" do
    assert_not_nil @weather_service
  end

  test "should normalize postal code" do
    # Test that postal codes are normalized (uppercase, no spaces)
    assert_equal "N1J0K3", @weather_service.send(:normalize_postal_code, "n1j0k3")
    assert_equal "N1J0K3", @weather_service.send(:normalize_postal_code, " N1J0K3 ")
    assert_equal "N1J0K3", @weather_service.send(:normalize_postal_code, "n1j 0k3")
  end

  test "should generate correct cache key" do
    cache_key = @weather_service.send(:cache_key, @normalized_postal_code)
    assert_equal "weather_service:N1E0K7", cache_key
  end

  test "should return cached data when available" do
    # Mock the API response
    mock_response = {
      "last_updated" => "2025-07-29 23:30",
      "last_updated_epoch" => 1753846200,
      "temp_c" => 21.1,
      "temp_f" => 70.0,
      "feelslike_c" => 21.1,
      "feelslike_f" => 70.0,
      "windchill_c" => 21.9,
      "windchill_f" => 71.5,
      "maxtemp_c" => 25.0,
      "maxtemp_f" => 77.0,
      "mintemp_c" => 18.0,
      "mintemp_f" => 64.4
    }
    
    # Cache the mock data
    Rails.cache.write(
      @weather_service.send(:cache_key, @normalized_postal_code),
      mock_response,
      expires_in: 30.minutes
    )

    # Mock Net::HTTP to ensure it's not called (since we have cached data)
    Net::HTTP.stubs(:get_response).never

    # Should return cached data without calling API
    result = @weather_service.get_weather(@postal_code)
    assert_equal mock_response, result
  end

  test "should call API when cache is empty" do
    # Mock the HTTP response
    mock_http_response = mock
    mock_http_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    mock_http_response.stubs(:body).returns({
      "current" => {
        "last_updated" => "2025-07-29 23:30",
        "last_updated_epoch" => 1753846200,
        "temp_c" => 21.1,
        "temp_f" => 70.0,
        "feelslike_c" => 21.1,
        "feelslike_f" => 70.0,
        "windchill_c" => 21.9,
        "windchill_f" => 71.5,
        "maxtemp_c" => 25.0,
        "maxtemp_f" => 77.0,
        "mintemp_c" => 18.0,
        "mintemp_f" => 64.4
      }
    }.to_json)

    # Mock Net::HTTP.get_response
    Net::HTTP.stubs(:get_response).returns(mock_http_response)

    result = @weather_service.get_weather(@postal_code)
    
    assert_not_nil result
    assert_equal "2025-07-29 23:30", result["last_updated"]
    assert_equal 1753846200, result["last_updated_epoch"]
    assert_equal 21.1, result["temp_c"]
    assert_equal 70.0, result["temp_f"]
  end

  test "should cache API response" do
    # Mock the HTTP response
    mock_http_response = mock
    mock_http_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    mock_http_response.stubs(:body).returns({
      "current" => {
        "last_updated" => "2025-07-29 23:30",
        "last_updated_epoch" => 1753846200,
        "temp_c" => 21.1,
        "temp_f" => 70.0,
        "feelslike_c" => 21.1,
        "feelslike_f" => 70.0,
        "windchill_c" => 21.9,
        "windchill_f" => 71.5,
        "maxtemp_c" => 25.0,
        "maxtemp_f" => 77.0,
        "mintemp_c" => 18.0,
        "mintemp_f" => 64.4
      }
    }.to_json)

    Net::HTTP.stubs(:get_response).returns(mock_http_response)

    # First call should cache the data
    @weather_service.get_weather(@postal_code)
    
    # Verify data is cached
    cache_key = @weather_service.send(:cache_key, @normalized_postal_code)
    cached_data = Rails.cache.read(cache_key)
    assert_not_nil cached_data
    assert_equal "2025-07-29 23:30", cached_data["last_updated"]
    assert_equal 21.1, cached_data["temp_c"]
  end

  test "should handle API errors gracefully" do
    # Mock HTTP error response
    mock_http_response = mock
    mock_http_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(false)
    mock_http_response.stubs(:code).returns("404")
    mock_http_response.stubs(:message).returns("Not Found")
    mock_http_response.stubs(:body).returns('{"error": {"code": 1006, "message": "No matching location found."}}')

    Net::HTTP.stubs(:get_response).returns(mock_http_response)

    assert_raises(RuntimeError) do
      @weather_service.get_weather(@postal_code)
    end
  end

  test "should handle network errors" do
    # Mock network error
    Net::HTTP.stubs(:get_response).raises(Net::OpenTimeout.new("Connection timeout"))

    assert_raises(RuntimeError) do
      @weather_service.get_weather(@postal_code)
    end
  end

  test "should build correct API URI" do
    uri = @weather_service.send(:build_api_uri, @postal_code)
    
    assert_equal "https", uri.scheme
    assert_equal "api.weatherapi.com", uri.host
    assert_equal "/v1/forecast.json", uri.path
    
    # Check query parameters
    query_params = URI.decode_www_form(uri.query).to_h
    assert_equal WeatherService::API_KEY, query_params["key"]
    assert_equal @postal_code, query_params["q"]
    assert_equal "1", query_params["days"]
    assert_equal "no", query_params["aqi"]
    assert_equal "no", query_params["alerts"]
  end

  test "should check if data is cached" do
    test_postal_code = "TEST123"
    normalized_test_postal_code = @weather_service.send(:normalize_postal_code, test_postal_code)
    
    # Initially not cached
    assert_not @weather_service.cached?(test_postal_code)
    
    # Cache some data
    Rails.cache.write(
      @weather_service.send(:cache_key, normalized_test_postal_code),
      {"test" => "data"},
      expires_in: 30.minutes
    )
    
    # Should be cached now
    assert @weather_service.cached?(test_postal_code)
  end

  test "should clear cache for specific postal code" do
    # Cache data for multiple postal codes
    postal_code_1 = "TEST456"
    postal_code_2 = "TEST789"
    
    Rails.cache.write(
      @weather_service.send(:cache_key, postal_code_1),
      {"data" => "test1"},
      expires_in: 30.minutes
    )
    
    Rails.cache.write(
      @weather_service.send(:cache_key, postal_code_2),
      {"data" => "test2"},
      expires_in: 30.minutes
    )
    
    # Clear cache for specific postal code
    @weather_service.clear_cache(postal_code_1)
    
    # First postal code should not be cached
    assert_not @weather_service.cached?(postal_code_1)
    
    # Second postal code should still be cached
    assert @weather_service.cached?(postal_code_2)
  end

  test "should clear all cache when no postal code specified" do
    # Cache data for multiple postal codes
    postal_code_1 = "TESTABC"
    postal_code_2 = "TESTDEF"
    
    Rails.cache.write(
      @weather_service.send(:cache_key, postal_code_1),
      {"data" => "test1"},
      expires_in: 30.minutes
    )
    
    Rails.cache.write(
      @weather_service.send(:cache_key, postal_code_2),
      {"data" => "test2"},
      expires_in: 30.minutes
    )
    
    # Clear all cache
    @weather_service.clear_cache
    
    # Both should not be cached
    assert_not @weather_service.cached?(postal_code_1)
    assert_not @weather_service.cached?(postal_code_2)
  end

  test "should handle empty postal code" do
    assert_raises(RuntimeError) do
      @weather_service.get_weather("")
    end
  end

  test "should handle nil postal code" do
    assert_raises(RuntimeError) do
      @weather_service.get_weather(nil)
    end
  end

  test "should handle special characters in postal code" do
    # Test with postal code containing special characters
    special_postal_code = "N1E-0K7"
    normalized = @weather_service.send(:normalize_postal_code, special_postal_code)
    
    # Should normalize to uppercase and remove special characters
    assert_equal "N1E0K7", normalized
  end

  test "should filter weather data correctly" do
    # Test with full API response
    full_response = {
      "location" => {"name" => "Guelph", "country" => "Canada"},
      "current" => {
        "last_updated" => "2025-07-29 23:30",
        "last_updated_epoch" => 1753846200,
        "temp_c" => 21.1,
        "temp_f" => 70.0,
        "feelslike_c" => 21.1,
        "feelslike_f" => 70.0,
        "windchill_c" => 21.9,
        "windchill_f" => 71.5,
        "humidity" => 88,
        "condition" => {"text" => "Clear"}
      }
    }
    
    filtered = @weather_service.send(:filter_weather_data, full_response)
    
    # Should only contain the required fields
    expected_fields = [
      "last_updated", "last_updated_epoch", "temp_c", "temp_f",
      "feelslike_c", "feelslike_f", "windchill_c", "windchill_f"
    ]
    
    expected_fields.each do |field|
      assert_not_nil filtered[field], "Missing field: #{field}"
    end
    
    # Should not contain other fields
    assert_nil filtered["humidity"]
    assert_nil filtered["condition"]
    assert_nil filtered["location"]
  end

  test "should handle empty weather data in filter" do
    # Test with nil data
    filtered = @weather_service.send(:filter_weather_data, nil)
    assert_equal({}, filtered)
    
    # Test with empty data
    filtered = @weather_service.send(:filter_weather_data, {})
    assert_equal({}, filtered)
    
    # Test with data missing current section
    filtered = @weather_service.send(:filter_weather_data, {"location" => {"name" => "Guelph"}})
    assert_equal({}, filtered)
  end
end 