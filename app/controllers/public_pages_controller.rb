class PublicPagesController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def sms_consent
      render :sms_consent
  end
end