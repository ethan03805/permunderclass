require "set"

class DisposableEmailBlocklist
  DOMAINS_PATH = Rails.root.join("config/disposable_email_domains.txt")

  class << self
    def include?(email)
      domains.include?(email.to_s.split("@").last.to_s.strip.downcase)
    end

    def reset!
      @domains = nil
    end

    private

    def domains
      @domains ||= Set.new(file_domains + env_domains)
    end

    def file_domains
      return [] unless DOMAINS_PATH.exist?

      DOMAINS_PATH.read.split(/\R/).filter_map do |line|
        normalize_domain(line)
      end
    end

    def env_domains
      ENV.fetch("DISPOSABLE_EMAIL_DOMAINS", "").split(",").filter_map do |domain|
        normalize_domain(domain)
      end
    end

    def normalize_domain(value)
      domain = value.to_s.strip.downcase
      return if domain.blank? || domain.start_with?("#")

      domain
    end
  end
end
