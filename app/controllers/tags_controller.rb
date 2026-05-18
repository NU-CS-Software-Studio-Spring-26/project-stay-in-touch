class TagsController < ApplicationController
  def index
    @tags = current_user.tags.includes(:people).order(:name)
  end

  def update
    tag = current_user.tags.find(params[:id])
    if tag.update(name: params.dig(:tag, :name).to_s.strip)
      redirect_to tags_path, notice: "Tag renamed to '#{tag.name}'."
    else
      redirect_to tags_path, alert: tag.errors.full_messages.to_sentence
    end
  end

  def destroy
    tag = current_user.tags.find(params[:id])
    tag.destroy
    redirect_to tags_path, notice: "Tag deleted.", status: :see_other
  end
end
