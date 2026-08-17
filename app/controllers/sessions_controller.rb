class SessionsController < ApplicationController
  def new; end
  def create
    user = User.find_by(email: params[:email].to_s.downcase)
    if user&.authenticate(params[:password])
      session[:user_id]=user.id; redirect_to root_path, notice: "Bienvenido #{user.name}"
    else
      flash.now[:alert]="Email o pass malos"; render :new
    end
  end
  def destroy; session[:user_id]=nil; redirect_to root_path, notice: "Logout"; end
end
