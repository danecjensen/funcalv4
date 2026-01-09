class LikesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post

  def create
    @post.like

    respond_to do |format|
      format.turbo_stream { render_like_update }
      format.html { redirect_to @post }
    end
  end

  def destroy
    @post.unlike

    respond_to do |format|
      format.turbo_stream { render_like_update }
      format.html { redirect_to @post }
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def render_like_update
    render turbo_stream: turbo_stream.replace(
      "like_button_#{@post.id}",
      partial: "posts/like_button",
      locals: { post: @post }
    )
  end
end
