require "test_helper"

class WeatherControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get weather_path
    assert_response :success
    assert_select "h1", "🌤️ Weather API"
  end

  test "should get docs" do
    get docs_path
    assert_response :success
    assert_select "h1", "Weather API Documentation"
  end

  test "should get root" do
    get root_path
    assert_response :success
    assert_select "h1", "🌤️ Weather API"
  end
end 