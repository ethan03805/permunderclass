class LoginFailureTracker
  IP_PREFIX = "login-failure:ip".freeze
  USER_PREFIX = "login-failure:user".freeze
  IP_LIMIT = 10
  USER_LIMIT = 5
  WINDOW = 15.minutes

  class << self
    def blocked?(ip_address)
      read(ip_key(ip_address)) >= IP_LIMIT
    end

    def blocked_user?(user_id)
      return false if user_id.blank?

      read(user_key(user_id)) >= USER_LIMIT
    end

    def track(ip_address)
      increment(ip_key(ip_address)) if ip_address.present?
    end

    def track_user(user_id)
      increment(user_key(user_id)) if user_id.present?
    end

    def reset(ip_address)
      Rails.cache.delete(ip_key(ip_address)) if ip_address.present?
    end

    def reset_user(user_id)
      Rails.cache.delete(user_key(user_id)) if user_id.present?
    end

    def count(ip_address)
      read(ip_key(ip_address))
    end

    private

    def ip_key(ip_address)
      "#{IP_PREFIX}:#{ip_address}"
    end

    def user_key(user_id)
      "#{USER_PREFIX}:#{user_id}"
    end

    def read(key)
      Rails.cache.read(key).to_i
    end

    def increment(key)
      new_value = Rails.cache.increment(key, 1, expires_in: WINDOW)
      return new_value if new_value

      current = Rails.cache.read(key).to_i + 1
      Rails.cache.write(key, current, expires_in: WINDOW)
      current
    end
  end
end
