module RateLimitable
  extend ActiveSupport::Concern

  # No automatic before_action - controllers should add it manually

  private

  def check_rate_limit
    ip_address = request.remote_ip
    cache_key = "rate_limit:#{ip_address}:#{Date.current}"

    # Get current request count for today
    current_count = Rails.cache.read(cache_key) || 0

    # Check if limit exceeded
    if current_count >= daily_limit
      render_rate_limit_exceeded
      return
    end

    # Increment request count
    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.day)
  end

  def render_rate_limit_exceeded
    render json: {
      status: 'error',
      error: 'Rate limit exceeded. Maximum 100 requests per day per IP address.',
      rate_limit_info: {
        limit: daily_limit,
        reset_time: Date.current.next_day.beginning_of_day.iso8601,
        message: 'Rate limit resets daily at midnight UTC'
      }
    }, status: :too_many_requests
  end

  def daily_limit
    100
  end

  def get_rate_limit_info(ip_address)
    cache_key = "rate_limit:#{ip_address}:#{Date.current}"
    current_count = Rails.cache.read(cache_key) || 0

    {
      current_requests: current_count,
      limit: daily_limit,
      remaining: [daily_limit - current_count, 0].max,
      reset_time: Date.current.next_day.beginning_of_day.iso8601
    }
  end
end
