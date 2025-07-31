module Api
  class WeatherController < ApplicationController
    include RateLimitable

    before_action :check_rate_limit, only: [:current]
    before_action :validate_input, only: [:current]

    def current
      # Extract postal code from user input
      postal_code_result = PostalCodeService.new.validate_and_extract_postal_code(params[:location])

      unless postal_code_result[:valid]
        render json: {
          error: postal_code_result[:error],
          status: 'error'
        }, status: :bad_request
        return
      end

      # Get weather data using the extracted postal code
      weather_result = WeatherService.new.get_weather(postal_code_result[:postal_code])

      render json: {
        status: 'success',
        data: {
          weather: weather_result[:data],
          from_cache: weather_result[:from_cache],
          location: {
            postal_code: postal_code_result[:postal_code],
            country: postal_code_result[:country]
          }
        },
        rate_limit: get_rate_limit_info(request.remote_ip)
      }
    rescue StandardError => e
      Rails.logger.error "Weather API error: #{e.message}"
      render json: {
        error: 'Failed to fetch weather data',
        status: 'error'
      }, status: :internal_server_error
    end

    private

    def validate_input
      return if params[:location].present?

      render json: {
        error: 'Location parameter is required',
        status: 'error'
      }, status: :bad_request
    end
  end
end
