class StaticPagesController < ApplicationController
  VALID_PAGES = %w[about rules faq privacy terms].freeze

  def show
    @page_key = params[:page_key].to_s
    raise ActiveRecord::RecordNotFound unless VALID_PAGES.include?(@page_key)

    @page = I18n.t("static_pages.#{@page_key}", default: {}).deep_stringify_keys
    raise ActiveRecord::RecordNotFound if @page.blank?
  end
end
