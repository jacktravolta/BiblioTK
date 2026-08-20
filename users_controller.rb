class UsersController < ApplicationController
  before_action :require_admin

  def index
    @users = User.all
  end

  def ban
    @user = User.find(params[:id])
    @banned_books = Book.joins(:reviews).where(reviews: { user_id: @user.id }).distinct
    @user.ban_by!(current_user, reason: params[:reason])
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} baneado. Ratings recalculados O(1)" }
    end
  end

  def unban
    @user = User.find(params[:id])
    @user.unban_by!(current_user)
    redirect_back fallback_location: users_path, notice: "Usuario desbaneado"
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to books_path, alert: "Solo admin"
    end
  end
end
