require "test_helper"

class RateLimitableTest < ActionDispatch::IntegrationTest
  setup do
    # Clear cache before each test
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "should include rate limit info in successful responses" do
    # Mock the services
    postal_code_result = {
      valid: true,
      country: 'US',
      postal_code: '10001',
      error: nil
    }
    
    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'temp_c' => 20.5,
      'temp_f' => 68.9
    }

    weather_result = {
      data: weather_data,
      from_cache: false
    }

    PostalCodeService.any_instance.stubs(:validate_and_extract_postal_code).returns(postal_code_result)
    WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

    # Make a request
    get api_weather_current_path, params: { location: '10001' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal 'success', json_response['status']
    assert_includes json_response, 'rate_limit'
    assert_equal 100, json_response['rate_limit']['limit']
    assert_equal 99, json_response['rate_limit']['remaining']
  end

  test "should increment rate limit counter on each request" do
    # Mock the services
    postal_code_result = {
      valid: true,
      country: 'US',
      postal_code: '10001',
      error: nil
    }
    
    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'temp_c' => 20.5,
      'temp_f' => 68.9
    }

    weather_result = {
      data: weather_data,
      from_cache: false
    }

    PostalCodeService.any_instance.stubs(:validate_and_extract_postal_code).returns(postal_code_result)
    WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

    # Make first request
    get api_weather_current_path, params: { location: '10001' }
    assert_response :success
    
    json_response_1 = JSON.parse(response.body)
    assert_equal 1, json_response_1['rate_limit']['current_requests']
    assert_equal 99, json_response_1['rate_limit']['remaining']
    
    # Make second request
    get api_weather_current_path, params: { location: '10001' }
    assert_response :success
    
    json_response_2 = JSON.parse(response.body)
    assert_equal 2, json_response_2['rate_limit']['current_requests']
    assert_equal 98, json_response_2['rate_limit']['remaining']
  end

  test "should handle rate limit exceeded scenario" do
    # This test simulates what happens when rate limit is exceeded
    # We'll manually set the cache to the limit and verify the response format
    
    ip_address = '127.0.0.1' # localhost
    cache_key = "rate_limit:#{ip_address}:#{Date.current.to_s}"
    
    # Set the request count to the limit
    Rails.cache.write(cache_key, 100, expires_in: 1.day)
    
    # Try to make a request - should get rate limit exceeded
    get api_weather_current_path, params: { location: '10001' }
    
    # Should get rate limit exceeded
    assert_response :too_many_requests
    json_response = JSON.parse(response.body)
    
    assert_equal 'error', json_response['status']
    assert_equal 'Rate limit exceeded. Maximum 100 requests per day per IP address.', json_response['error']
    assert_includes json_response, 'rate_limit_info'
    assert_equal 100, json_response['rate_limit_info']['limit']
  end

  test "should reset rate limit daily" do
    # Test that rate limit resets daily by clearing cache
    ip_address = '127.0.0.1'
    cache_key = "rate_limit:#{ip_address}:#{Date.current.to_s}"
    
    # Set request count to limit
    Rails.cache.write(cache_key, 100, expires_in: 1.day)
    
    # Should be blocked
    get api_weather_current_path, params: { location: '10001' }
    assert_response :too_many_requests
    
    # Clear cache (simulating new day)
    Rails.cache.clear
    
    # Mock services for successful request
    postal_code_result = {
      valid: true,
      country: 'US',
      postal_code: '10001',
      error: nil
    }
    
    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'temp_c' => 20.5,
      'temp_f' => 68.9
    }

    weather_result = {
      data: weather_data,
      from_cache: false
    }

    PostalCodeService.any_instance.stubs(:validate_and_extract_postal_code).returns(postal_code_result)
    WeatherService.any_instance.stubs(:get_weather).returns(weather_result)
    
    # Should be allowed again
    get api_weather_current_path, params: { location: '10001' }
    assert_response :success
  end
end 