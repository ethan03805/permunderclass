class LoginFailureTracker
  KEY_PREFIX = "login-failure".freeze
  LIMIT = 10
  WINDOW = 15.minutes

  class << self
    def blocked?(ip_address)
      count(ip_address) >= LIMIT
    end

    def count(ip_address)
      return 0 if ip_address.blank?

      Rails.cache.read(cache_key(ip_address)).to_i
    end

    def reset(ip_address)
      return if ip_address.blank?

      Rails.cache.delete(cache_key(ip_address))
    end

    def track(ip_address)
      return if ip_address.blank?

      key = cache_key(ip_address)
      new_value = Rails.cache.increment(key, 1, expires_in: WINDOW)
      return new_value if new_value

      current = Rails.cache.read(key).to_i + 1
      Rails.cache.write(key, current, expires_in: WINDOW)
      current
    end

    private

    def cache_key(ip_address)
      "#{KEY_PREFIX}:#{ip_address}"
    end
  end
end
