require "test_helper"

class Api::WeatherControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Clear cache before each test
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "should get current weather with valid US postal code" do
    # Mock the services
    postal_code_result = {
      valid: true,
      country: 'US',
      postal_code: '12345',
      error: nil
    }
    
    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'last_updated_epoch' => 1705312800,
      'temp_c' => 20.5,
      'temp_f' => 68.9,
      'feelslike_c' => 22.0,
      'feelslike_f' => 71.6,
      'windchill_c' => 21.0,
      'windchill_f' => 69.8,
      'maxtemp_c' => 25.0,
      'maxtemp_f' => 77.0,
      'mintemp_c' => 15.0,
      'mintemp_f' => 59.0
    }

    weather_result = {
      data: weather_data,
      from_cache: false
    }

    PostalCodeService.any_instance.stubs(:validate_and_extract_postal_code).returns(postal_code_result)
    WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

    get api_weather_current_path, params: { location: '12345 Main St, New York, NY 12345' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal 'success', json_response['status']
    assert_equal '12345', json_response['data']['location']['postal_code']
    assert_equal 'US', json_response['data']['location']['country']
    assert_equal 20.5, json_response['data']['weather']['temp_c']
    assert_equal 68.9, json_response['data']['weather']['temp_f']
    assert_equal false, json_response['data']['from_cache']
    assert_includes json_response, 'rate_limit'
    assert_equal 100, json_response['rate_limit']['limit']
  end

  test "should get current weather with valid Canadian postal code" do
    # Mock the services
    postal_code_result = {
      valid: true,
      country: 'CA',
      postal_code: 'A1A 1A1',
      error: nil
    }
    
    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'last_updated_epoch' => 1705312800,
      'temp_c' => 15.2,
      'temp_f' => 59.4,
      'feelslike_c' => 16.0,
      'feelslike_f' => 60.8,
      'windchill_c' => 14.0,
      'windchill_f' => 57.2,
      'maxtemp_c' => 18.0,
      'maxtemp_f' => 64.4,
      'mintemp_c' => 10.0,
      'mintemp_f' => 50.0
    }

    weather_result = {
      data: weather_data,
      from_cache: true
    }

    PostalCodeService.any_instance.stubs(:validate_and_extract_postal_code).returns(postal_code_result)
    WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

    get api_weather_current_path, params: { location: '123 Main St, Toronto, ON A1A 1A1' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal 'success', json_response['status']
    assert_equal 'A1A 1A1', json_response['data']['location']['postal_code']
    assert_equal 'CA', json_response['data']['location']['country']
    assert_equal 15.2, json_response['data']['weather']['temp_c']
    assert_equal 59.4, json_response['data']['weather']['temp_f']
    assert_equal true, json_response['data']['from_cache']
    assert_includes json_response, 'rate_limit'
    assert_equal 100, json_response['rate_limit']['limit']
  end

  test "should return error for missing location parameter" do
    get api_weather_current_path
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal 'error', json_response['status']
    assert_equal 'Location parameter is required', json_response['error']
  end

  test "should return error for empty location parameter" do
    get api_weather_current_path, params: { location: '' }
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal 'error', json_response['status']
    assert_equal 'Location parameter is required', json_response['error']
  end

  test "should return error for invalid postal code in address" do
    get api_weather_current_path, params: { location: 'Invalid Address 1234' }
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal 'error', json_response['status']
    assert_equal 'No valid postal code found in address', json_response['error']
  end

  test "should return error for address without postal code" do
    get api_weather_current_path, params: { location: '123 Main Street, City, State' }
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal 'error', json_response['status']
    assert_equal 'No valid postal code found in address', json_response['error']
  end

  test "should handle weather service errors gracefully" do
    # Mock HTTP error response
    mock_http_response = mock
    mock_http_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(false)
    mock_http_response.stubs(:code).returns("404")
    mock_http_response.stubs(:message).returns("Not Found")
    mock_http_response.stubs(:body).returns('{"error": {"code": 1006, "message": "No matching location found."}}')

    Net::HTTP.stubs(:get_response).returns(mock_http_response)

    get api_weather_current_path, params: { location: '12345 Main St' }
    
    assert_response :internal_server_error
    json_response = JSON.parse(response.body)
    
    assert_equal 'error', json_response['status']
    assert_equal 'Failed to fetch weather data', json_response['error']
  end

  test "should handle various US postal code formats" do
    test_cases = [
      { input: '12345', expected: '12345' },
      { input: '12345-6789', expected: '12345-6789' },
      { input: '12345 Main St, New York, NY 12345', expected: '12345' },
      { input: 'Address: 12345-6789, City, State', expected: '12345-6789' }
    ]

    test_cases.each do |test_case|
      # Mock the services for each test case
      postal_code_result = {
        valid: true,
        country: 'US',
        postal_code: test_case[:expected],
        error: nil
      }
      
      weather_data = {
        'last_updated' => '2024-01-15 12:00',
        'last_updated_epoch' => 1705312800,
        'temp_c' => 20.0,
        'temp_f' => 68.0,
        'feelslike_c' => 22.0,
        'feelslike_f' => 71.6,
        'windchill_c' => 21.0,
        'windchill_f' => 69.8,
        'maxtemp_c' => 25.0,
        'maxtemp_f' => 77.0,
        'mintemp_c' => 15.0,
        'mintemp_f' => 59.0
      }

      weather_result = {
        data: weather_data,
        from_cache: false
      }

      PostalCodeService.any_instance.stubs(:validate_and_extract_postal_code).returns(postal_code_result)
      WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

      get api_weather_current_path, params: { location: test_case[:input] }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      
      assert_equal 'success', json_response['status']
      assert_equal test_case[:expected], json_response['data']['location']['postal_code']
    end
  end

  test "should handle various Canadian postal code formats" do
    test_cases = [
      { input: 'A1A 1A1', expected: 'A1A 1A1' },
      { input: 'A1A1A1', expected: 'A1A 1A1' },
      { input: 'A1A-1A1', expected: 'A1A 1A1' },
      { input: '123 Main St, Toronto, ON A1A 1A1', expected: 'A1A 1A1' }
    ]

    test_cases.each do |test_case|
      # Mock the services for each test case
      postal_code_result = {
        valid: true,
        country: 'CA',
        postal_code: test_case[:expected],
        error: nil
      }
      
      weather_data = {
        'last_updated' => '2024-01-15 12:00',
        'last_updated_epoch' => 1705312800,
        'temp_c' => 15.0,
        'temp_f' => 59.0,
        'feelslike_c' => 16.0,
        'feelslike_f' => 60.8,
        'windchill_c' => 14.0,
        'windchill_f' => 57.2,
        'maxtemp_c' => 18.0,
        'maxtemp_f' => 64.4,
        'mintemp_c' => 10.0,
        'mintemp_f' => 50.0
      }

      weather_result = {
        data: weather_data,
        from_cache: true
      }

      PostalCodeService.any_instance.stubs(:validate_and_extract_postal_code).returns(postal_code_result)
      WeatherService.any_instance.stubs(:get_weather).returns(weather_result)

      get api_weather_current_path, params: { location: test_case[:input] }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      
      assert_equal 'success', json_response['status']
      assert_equal test_case[:expected], json_response['data']['location']['postal_code']
      assert_equal 'CA', json_response['data']['location']['country']
    end
  end
end 