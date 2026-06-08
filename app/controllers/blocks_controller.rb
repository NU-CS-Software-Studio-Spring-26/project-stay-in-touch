class BlocksController < ApplicationController
  def create
    blocked = User.find(params[:blocked_id])
    current_user.blocks.find_or_create_by!(blocked: blocked)
    redirect_back fallback_location: matches_path,
                  notice: "#{blocked.display_label} has been blocked and will no longer appear in matchmaking."
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: matches_path, alert: "User not found."
  end

  def destroy
    block = current_user.blocks.find(params[:id])
    label = block.blocked.display_label
    block.destroy
    redirect_back fallback_location: matches_path, notice: "#{label} has been unblocked."
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: matches_path, alert: "Block not found."
  end
end
