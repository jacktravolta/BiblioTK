class ReviewsController < ApplicationController
  before_action { redirect_to login_path unless current_user }
  def create
    @book=Book.find(params[:book_id])
    @review=@book.reviews.build(review_params.merge(user: current_user))
    if @review.save; redirect_to book_path(@book), notice: "Reseña creada"
    else; redirect_to book_path(@book), alert: @review.errors.full_messages.join(", "); end
  end
  def update
    @review=current_user.reviews.find(params[:id])
    @review.update(review_params); redirect_to book_path(@review.book), notice: "Actualizada"
  end
  def destroy
    @review=current_user.reviews.find(params[:id]); b=@review.book; @review.destroy; redirect_to book_path(b), notice: "Borrada"
  end
  private; def review_params; params.require(:review).permit(:stars, :content); end
end
