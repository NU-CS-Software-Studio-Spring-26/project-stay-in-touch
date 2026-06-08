class PushSubscriptionsController < ApplicationController
  def create
    data = JSON.parse(request.body.read)
    current_user.push_subscriptions.find_or_create_by!(endpoint: data["endpoint"]) do |sub|
      sub.p256dh_key = data.dig("keys", "p256dh")
      sub.auth_key   = data.dig("keys", "auth")
    end
    head :created
  rescue JSON::ParserError, ActionController::ParameterMissing
    head :unprocessable_entity
  end

  def destroy
    current_user.push_subscriptions.find_by(endpoint: params[:endpoint])&.destroy
    head :no_content
  end
end
