class PwaController < ApplicationController
  allow_unauthenticated_access
  allow_browser versions: :all
  skip_forgery_protection

  def manifest
    render layout: false
  end

  def service_worker
    render layout: false
  end

  def offline; end
end
