class UsersController < ApplicationController
  before_action :require_admin, only: [:index, :ban, :unban]
  before_action :set_user, only: [:show, :ban, :unban]

  def index
    @per_page = 20
    @page = [params[:page].to_i, 1].max
    @total_count = User.count
    @total_pages = (@total_count.to_f / @per_page).ceil
    @users = User.order(:id).limit(@per_page).offset((@page - 1) * @per_page)
  end

  def show
    @reviews_page = [params[:reviews_page].to_i, 1].max
    @reviews_per_page = 10
    @reviews_total = @user.reviews.count
    @reviews_total_pages = (@reviews_total.to_f / @reviews_per_page).ceil
    @reviews = @user.reviews.includes(:book).order(created_at: :desc).limit(@reviews_per_page).offset((@reviews_page - 1) * @reviews_per_page)
  end

  def ban
    if @user.id == current_user.id
      redirect_back fallback_location: users_path, alert: "No puedes banearte a ti mismo"
      return
    end
    @user.ban_by!(current_user, reason: params[:reason] || "Baneado desde admin - #{request.referer}")
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} baneado - ratings recalculados O(1)"
  rescue => e
    redirect_back fallback_location: users_path, alert: "Error: #{e.message}"
  end

  def unban
    @user.unban_by!(current_user)
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} reactivado"
  rescue => e
    redirect_back fallback_location: users_path, alert: "Error: #{e.message}"
  end

  private
  def set_user
    @user = User.find(params[:id])
  end

  def require_admin
    unless current_user&.admin?
      redirect_to books_path, alert: "Solo admin puede gestionar usuarios"
    end
  end
end
