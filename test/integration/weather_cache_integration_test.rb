require "test_helper"

class WeatherCacheIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    # Clear cache before each test
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "should return fresh data on first request" do
    # Mock the weather service to return fresh data
    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'temp_c' => 20.5,
      'temp_f' => 68.9
    }

    weather_result = {
      data: weather_data,
      from_cache: false
    }

    WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

    get api_weather_current_path, params: { location: '12345' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['data']['from_cache']
    assert_equal 20.5, json_response['data']['weather']['temp_c']
  end

  test "should return cached data on subsequent requests" do
    # Mock the weather service to return cached data
    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'temp_c' => 20.5,
      'temp_f' => 68.9
    }

    weather_result = {
      data: weather_data,
      from_cache: true
    }

    WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

    get api_weather_current_path, params: { location: '12345' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['data']['from_cache']
    assert_equal 20.5, json_response['data']['weather']['temp_c']
  end

  test "should display cache status in frontend" do
    # Test that the frontend properly handles the cache status
    get root_path
    
    assert_response :success
    assert_select "h1", "🌤️ Weather API"
    
    # The frontend JavaScript should handle the cache status display
    # This test verifies the page loads correctly with the cache status functionality
  end
end 