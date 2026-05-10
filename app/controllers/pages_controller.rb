class PagesController < ApplicationController
  allow_unauthenticated_access

  def privacy; end
  def about; end
end
