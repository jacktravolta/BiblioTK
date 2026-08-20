class UsersController < ApplicationController
  before_action :require_admin

  def index
    @q = params[:q]
    @page = (params[:page] || 1).to_i
    per_page = 10
    scope = User.all
    scope = scope.where("email ILIKE ? OR name ILIKE ?", "%#{@q}%", "%#{@q}%") if @q.present?
    scope = scope.where(banned: true) if params[:filter] == "banned"
    scope = scope.where(banned: false) if params[:filter] == "active"
    @total_count = scope.count
    @total_pages = (@total_count.to_f / per_page).ceil
    @total_pages = 1 if @total_pages == 0
    @users = scope.order(:id).offset((@page - 1) * per_page).limit(per_page)
  end

  def ban
    @user = User.find(params[:id])
    @banned_books = Book.joins(:reviews).where(reviews: { user_id: @user.id }).distinct.to_a
    @user.ban_by!(current_user, reason: params[:reason])
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to request.referer || users_path, notice: "Baneado" }
    end
  end

  def unban
    @user = User.find(params[:id])
    @banned_books = Book.joins(:reviews).where(reviews: { user_id: @user.id }).distinct.to_a
    @user.unban_by!(current_user)
    respond_to do |format|
      format.turbo_stream { render :ban }
      format.html { redirect_to request.referer || users_path, notice: "Desbaneado" }
    end
  end

  private
  def require_admin
    redirect_to books_path, alert: "Solo admin" unless current_user&.admin?
  end
end
