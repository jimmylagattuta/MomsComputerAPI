class PortalController < ActionController::Base
  def index
    render file: Rails.public_path.join("portal", "index.html"), layout: false
  end
end