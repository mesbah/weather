# Weather API

A Rails application that provides weather information by extracting postal codes from user input and fetching weather data from the WeatherAPI.com service.

## Features

- **Postal Code Extraction**: Automatically extracts and validates US ZIP codes and Canadian postal codes from addresses
- **Weather Data**: Fetches current weather information including temperature, feels like, wind chill, and more
- **Caching**: Implements 30-minute caching to reduce API calls and improve performance
- **Error Handling**: Comprehensive error handling for invalid inputs and API failures
- **Frontend Interface**: Modern, responsive web interface for easy testing
- **RESTful API**: Clean JSON API for programmatic access

## Supported Postal Code Formats

### US ZIP Codes

- 5-digit format: `12345`
- ZIP+4 format: `12345-6789`

### Canadian Postal Codes

- Standard format: `A1A 1A1`
- Compact format: `A1A1A1`
- With hyphen: `A1A-1A1`

## Quick Start

### Prerequisites

- Ruby 3.0+
- Rails 7.0+
- Redis (for caching)
- **WeatherAPI.com API key** - Get a free API key from [https://www.weatherapi.com/](https://www.weatherapi.com/)
  - Sign up for a free account
  - Free tier includes 1,000,000 calls per month

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd weather
```

2. Install dependencies:

```bash
bundle install
```

3. **Get your WeatherAPI.com API key**:

   - Visit [https://www.weatherapi.com/](https://www.weatherapi.com/)
   - Sign up for a free account
   - Get your API key from the dashboard

4. Set up environment variables:

```bash
# Create .env file or set in your environment
export WEATHER_API_KEY=your_weather_api_key_here
```

5. Start the server:

```bash
bin/rails server
```

6. Visit the application:
   - Frontend: http://localhost:3000
   - API: http://localhost:3000/api/weather/current?location=10001

## API Documentation

### Endpoint

```
GET /api/weather/current
```

### Parameters

| Parameter | Type   | Required | Description            |
| --------- | ------ | -------- | ---------------------- |
| location  | string | Yes      | Address or postal code |

### Response Format

#### Success Response (200)

```json
{
  "status": "success",
  "data": {
    "weather": {
      "last_updated": "2024-01-15 12:00",
      "last_updated_epoch": 1705312800,
      "temp_c": 20.5,
      "temp_f": 68.9,
      "feelslike_c": 22.0,
      "feelslike_f": 71.6,
      "windchill_c": 21.0,
      "windchill_f": 69.8,
      "maxtemp_c": 25.0,
      "maxtemp_f": 77.0,
      "mintemp_c": 15.0,
      "mintemp_f": 59.0
    },
    "location": {
      "postal_code": "10001",
      "country": "US"
    }
  }
}
```

#### Error Response (400/500)

```json
{
  "status": "error",
  "error": "Error message description"
}
```

### Usage Examples

#### US ZIP Codes

```bash
# 5-digit ZIP
curl "http://localhost:3000/api/weather/current?location=10001"

# ZIP+4 format
curl "http://localhost:3000/api/weather/current?location=90210-1234"

# Full address with ZIP
curl "http://localhost:3000/api/weather/current?location=123%20Main%20St,%20New%20York,%20NY%2010001"
```

#### Canadian Postal Codes

```bash
# Standard format
curl "http://localhost:3000/api/weather/current?location=A1A%201A1"

# Compact format
curl "http://localhost:3000/api/weather/current?location=A1A1A1"

# Full address with postal code
curl "http://localhost:3000/api/weather/current?location=123%20Main%20St,%20Toronto,%20ON%20A1A%201A1"
```

### Error Codes

| HTTP Status | Error Message                         | Description                        |
| ----------- | ------------------------------------- | ---------------------------------- |
| 400         | Location parameter is required        | Missing location parameter         |
| 400         | Invalid postal code format            | Invalid postal code format         |
| 400         | No valid postal code found in address | No postal code found in address    |
| 500         | Failed to fetch weather data          | Weather API error or network issue |

## Services

### WeatherService

Handles weather data fetching and caching.

```ruby
weather_service = WeatherService.new
weather_data = weather_service.get_weather("10001")
```

**Methods:**

- `get_weather(postal_code)`: Fetch weather data for a postal code
- `clear_cache(postal_code)`: Clear cache for specific postal code
- `cached?(postal_code)`: Check if data is cached
- `cache_expiry(postal_code)`: Get cache expiry time

### PostalCodeService

Handles postal code extraction and validation.

```ruby
postal_service = PostalCodeService.new
result = postal_service.validate_and_extract_postal_code("123 Main St, NY 10001")
```

**Methods:**

- `validate_and_extract_postal_code(address)`: Extract and validate postal code from address
- `validate_postal_code(postal_code)`: Validate a postal code
- `extract_postal_code_from_address(address)`: Extract postal code from address

## Caching

The application implements a 30-minute cache for weather data to:

- Reduce API calls to WeatherAPI.com
- Improve response times
- Reduce costs

Cache keys follow the pattern: `weather_service:{postal_code}`

## Testing

Run the test suite:

```bash
# Run all tests
bin/rails test

# Run specific test files
bin/rails test test/controllers/api/weather_controller_test.rb
bin/rails test test/services/weather_service_test.rb
bin/rails test test/services/postal_code_service_test.rb
bin/rails test test/integration/weather_api_integration_test.rb
```

## Configuration

### Environment Variables

| Variable          | Description            | Required |
| ----------------- | ---------------------- | -------- |
| `WEATHER_API_KEY` | WeatherAPI.com API key | Yes      |

### Cache Configuration

The application uses Rails.cache for weather data caching. Configure your cache store in `config/environments/`:

```ruby
# For Redis
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }

# For memory (development)
config.cache_store = :memory_store
```

## Frontend

The application includes a modern, responsive frontend interface accessible at:

- http://localhost:3000 (root)
- http://localhost:3000/weather

Features:

- Real-time weather data display
- Support for all postal code formats
- Error handling and user feedback
- Mobile-responsive design
- Keyboard navigation support

## API Rate Limits

The application respects WeatherAPI.com rate limits:

- Free tier: 1,000,000 calls per month
- Paid tiers: Higher limits based on plan

The 30-minute cache helps stay within these limits.

## Error Handling

The application handles various error scenarios:

1. **Invalid Input**: Returns 400 with descriptive error messages
2. **API Errors**: Returns 500 with generic error message
3. **Network Issues**: Graceful handling of timeouts and connection errors
4. **Quota Exceeded**: Logs detailed error information for monitoring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:

1. Check the documentation above
2. Review existing issues
3. Create a new issue with detailed information
