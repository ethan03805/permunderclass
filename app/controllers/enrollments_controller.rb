class EnrollmentsController < ApplicationController
  before_action :load_user_from_token

  def show
    if enrollment_allowed?
      @user.begin_enrollment!
      @qr_svg = render_qr_svg(@user.totp_candidate_secret)
    end
  end

  def confirm
    return unless enrollment_allowed?

    ip = request.remote_ip
    if LoginFailureTracker.blocked?(ip) || LoginFailureTracker.blocked_user?(@user.id)
      redirect_to enroll_path(token: params[:token]), alert: t("auth.enrollment.rate_limited"), status: :see_other
      return
    end

    candidate = @user.totp_candidate_secret
    code = params.dig(:enrollment, :code).to_s

    if candidate.present? && verify_candidate(candidate, code)
      @user.complete_enrollment!
      LoginFailureTracker.reset(ip)
      LoginFailureTracker.reset_user(@user.id)
      start_session_for(@user)
      redirect_to root_path, notice: t("auth.enrollment.success"), status: :see_other
    else
      LoginFailureTracker.track(ip)
      LoginFailureTracker.track_user(@user.id)
      @user.begin_enrollment! if @user.totp_candidate_secret.blank?
      @qr_svg = render_qr_svg(@user.reload.totp_candidate_secret)
      flash.now[:alert] = t("auth.enrollment.invalid_code")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_user_from_token
    @user = User.find_by_token_for(:enrollment, params[:token])

    if @user.nil?
      redirect_to sign_in_path, alert: t("auth.enrollment.invalid_token")
      return
    end

    if @user.suspended? || @user.banned?
      redirect_to root_path, alert: blocked_user_message(@user)
    end
  end

  def enrollment_allowed?
    @user.present? && !@user.suspended? && !@user.banned?
  end

  def verify_candidate(candidate, code)
    return false if code.blank?

    ROTP::TOTP.new(candidate).verify(code, drift_behind: 30, drift_ahead: 30).present?
  end

  def render_qr_svg(secret)
    totp = ROTP::TOTP.new(secret, issuer: Rails.configuration.x.totp_issuer)
    uri = totp.provisioning_uri(@user.email)
    RQRCode::QRCode.new(uri).as_svg(standalone: true, module_size: 4, use_path: true)
  end
end
