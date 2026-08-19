class UsersController < ApplicationController
  before_action :require_admin

  def index
    per_page = 20
    @page = [(params[:page] || 1).to_i, 1].max
    @q = params[:q].to_s.strip

    scope = User.order(:id)
    
    if @q.present?
      # ILIKE para postgres, busca por nombre, email, role
      like = "%#{@q}%"
      scope = scope.where("name ILIKE ? OR email ILIKE ? OR role ILIKE ?", like, like, like)
    end

    # filtro extra opcional por estado
    if params[:filter] == "banned"
      scope = scope.where(banned: true)
    elsif params[:filter] == "active"
      scope = scope.where(banned: false)
    end

    @total_users = scope.count
    @total_pages = (@total_users.to_f / per_page).ceil
    @total_pages = 1 if @total_pages == 0
    @page = @total_pages if @page > @total_pages

    @users = scope.limit(per_page).offset((@page - 1) * per_page)
  end

  def ban
    @user = User.find(params[:id])
    @user.ban_by!(current_user, reason: params[:reason])
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} baneado. Ratings recalculados O(1)"
  end

  def unban
    @user = User.find(params[:id])
    @user.unban_by!(current_user)
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} desbaneado. Ratings recalculados O(1)"
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to books_path, alert: "Solo admin"
    end
  end
end
