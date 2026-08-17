class UsersController < ApplicationController
  before_action :require_admin, only: [:index, :ban, :unban]

  def index
    @per_page = 20
    @page = [params[:page].to_i, 1].max
    @page = 1 if @page < 1
    total = User.count
    @total_pages = (total.to_f / @per_page).ceil
    @total_pages = 1 if @total_pages == 0
    @page = @total_pages if @page > @total_pages
    offset = (@page - 1) * @per_page
    @users = User.order(:id).limit(@per_page).offset(offset)
    @total_count = total
  end

  def show
    @user = User.find(params[:id])
    @reviews_per_page = 10
    @reviews_page = [params[:reviews_page].to_i, 1].max
    @reviews_page = 1 if @reviews_page < 1
    total = @user.reviews.count
    @reviews_total_pages = (total.to_f / @reviews_per_page).ceil
    @reviews_total_pages = 1 if @reviews_total_pages == 0
    @reviews_page = @reviews_total_pages if @reviews_page > @reviews_total_pages
    offset = (@reviews_page - 1) * @reviews_per_page
    @reviews = @user.reviews.includes(:book).order(created_at: :desc).limit(@reviews_per_page).offset(offset)
    @reviews_total_count = total
  end

  def ban
    u = User.find(params[:id])
    if current_user.admin? && u.id!= current_user.id
      u.ban_by!(current_user, reason: params[:reason] || "Spam")
      redirect_back fallback_location: users_path, notice: "Baneado #{u.email} - O(1) reconciliado"
    else
      redirect_back fallback_location: users_path, alert: "No puedes banearte"
    end
  end

  def unban
    u = User.find(params[:id])
    u.unban_by!(current_user)
    redirect_back fallback_location: users_path, notice: "Reactivado #{u.email}"
  end

  private
  def require_admin
    redirect_to root_path, alert: "Solo ADMIN" unless current_user&.admin?
  end
end
