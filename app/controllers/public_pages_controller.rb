class PublicPagesController < ActionController::Base
  def sms_consent
    render :sms_consent, layout: false
  end
end