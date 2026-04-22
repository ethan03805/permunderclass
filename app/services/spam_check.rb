class SpamCheck
  Result = Struct.new(:allowed?, :error_key, keyword_init: true)

  CONTEXTS = {
    sign_up: { minimum_seconds: 3, expires_in: 2.hours },
    submit: { minimum_seconds: 5, expires_in: 6.hours }
  }.freeze

  def self.form_token_for(context, now: Time.current)
    context = normalize_context(context)
    verifier.generate({ context: context, started_at: now.to_f }, expires_in: configuration_for(context).fetch(:expires_in))
  end

  def self.configuration_for(context)
    CONTEXTS.fetch(normalize_context(context))
  end

  def self.normalize_context(context)
    context.to_s.to_sym
  end

  def self.verifier
    @verifier ||= Rails.application.message_verifier("spam-check")
  end

  def initialize(context:, honeypot_value:, form_started_token:, now: Time.current)
    @context = self.class.normalize_context(context)
    @honeypot_value = honeypot_value.to_s
    @form_started_token = form_started_token.to_s
    @now = now
  end

  def call
    return Result.new(allowed?: false, error_key: :honeypot_triggered) if honeypot_value.present?

    payload = self.class.verifier.verified(form_started_token)
    return Result.new(allowed?: false, error_key: :submission_token_invalid) if payload.blank?
    return Result.new(allowed?: false, error_key: :submission_token_invalid) if payload_value(payload, :context).to_s != context.to_s
    return Result.new(allowed?: false, error_key: :submitted_too_quickly) if elapsed_seconds(payload) < minimum_seconds

    Result.new(allowed?: true)
  end

  private

  attr_reader :context, :form_started_token, :honeypot_value, :now

  def elapsed_seconds(payload)
    now.to_f - payload_value(payload, :started_at).to_f
  end

  def minimum_seconds
    self.class.configuration_for(context).fetch(:minimum_seconds)
  end

  def payload_value(payload, key)
    payload[key] || payload[key.to_s]
  end
end
