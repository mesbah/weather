require 'test_helper'

class WeatherApiIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    # Clear cache before each test
    Rails.cache.clear
  end

  def teardown
    Rails.cache.clear
  end

  test 'should get weather for valid US address' do
    # Mock the services
    postal_code_result = {
      valid: true,
      country: 'US',
      postal_code: '10001',
      error: nil
    }

    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'last_updated_epoch' => 1_705_312_800,
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

    get api_weather_current_path, params: { location: '123 Main St, New York, NY 10001' }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 'success', json_response['status']
    assert_equal '10001', json_response['data']['location']['postal_code']
    assert_equal 'US', json_response['data']['location']['country']
    assert_equal 20.5, json_response['data']['weather']['temp_c']
    assert_equal 68.9, json_response['data']['weather']['temp_f']
  end

  test 'should get weather for valid Canadian address' do
    # Mock the services
    postal_code_result = {
      valid: true,
      country: 'CA',
      postal_code: 'A1A 1A1',
      error: nil
    }

    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'last_updated_epoch' => 1_705_312_800,
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
  end

  test 'should handle weather API errors gracefully' do
    # Mock HTTP error response
    mock_http_response = mock
    mock_http_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(false)
    mock_http_response.stubs(:code).returns('404')
    mock_http_response.stubs(:message).returns('Not Found')
    mock_http_response.stubs(:body).returns('{"error": {"code": 1006, "message": "No matching location found."}}')

    Net::HTTP.stubs(:get_response).returns(mock_http_response)

    get api_weather_current_path, params: { location: '123 Main St, New York, NY 10001' }

    assert_response :internal_server_error
    json_response = JSON.parse(response.body)

    assert_equal 'error', json_response['status']
    assert_equal 'Failed to fetch weather data', json_response['error']
  end

  test 'should handle network errors gracefully' do
    # Mock network error
    Net::HTTP.stubs(:get_response).raises(Net::OpenTimeout.new('Connection timeout'))

    get api_weather_current_path, params: { location: '123 Main St, New York, NY 10001' }

    assert_response :internal_server_error
    json_response = JSON.parse(response.body)

    assert_equal 'error', json_response['status']
    assert_equal 'Failed to fetch weather data', json_response['error']
  end

  test 'should cache weather data and return cached response' do
    # Mock the services
    postal_code_result = {
      valid: true,
      country: 'US',
      postal_code: '10001',
      error: nil
    }

    weather_data = {
      'last_updated' => '2024-01-15 12:00',
      'last_updated_epoch' => 1_705_312_800,
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

    # First request should call the API
    get api_weather_current_path, params: { location: '123 Main St, New York, NY 10001' }
    assert_response :success

    # Second request should use cached data
    get api_weather_current_path, params: { location: '123 Main St, New York, NY 10001' }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']
    assert_equal 20.5, json_response['data']['weather']['temp_c']
  end

  test 'should handle various input formats' do
    test_cases = [
      { input: '10001', expected_postal: '10001', expected_country: 'US' },
      { input: '10001-1234', expected_postal: '10001-1234', expected_country: 'US' },
      { input: 'A1A 1A1', expected_postal: 'A1A 1A1', expected_country: 'CA' },
      { input: 'A1A1A1', expected_postal: 'A1A 1A1', expected_country: 'CA' },
      { input: '123 Main St, New York, NY 10001', expected_postal: '10001', expected_country: 'US' },
      { input: '456 Oak Ave, Toronto, ON A1A 1A1', expected_postal: 'A1A 1A1', expected_country: 'CA' }
    ]

    test_cases.each do |test_case|
      # Mock the services for each test case
      postal_code_result = {
        valid: true,
        country: test_case[:expected_country],
        postal_code: test_case[:expected_postal],
        error: nil
      }

      weather_data = {
        'last_updated' => '2024-01-15 12:00',
        'last_updated_epoch' => 1_705_312_800,
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
      assert_equal test_case[:expected_postal], json_response['data']['location']['postal_code']
      assert_equal test_case[:expected_country], json_response['data']['location']['country']
    end
  end
end
