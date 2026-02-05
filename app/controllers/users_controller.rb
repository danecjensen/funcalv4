class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_user, except: [:profile]

  def profile
    redirect_to user_path(current_user)
  end

  def show
    @posts = @user.posts.includes(:event, :likes, :comments).recent
    @calendars = @user.calendars.includes(:events)
  end

  def edit
    authorize @user
  end

  def update
    authorize @user
    if @user.update(user_params)
      redirect_to @user, notice: "Profile updated!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :bio, :avatar)
  end
end
