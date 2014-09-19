class RatingsController < ApplicationController
  before_filter :require_admin

  def index
    @ratings = Rating.order('ratings.id DESC').includes(:user).joins(:reservation => :server).paginate(:page => params[:page], :per_page => 100)
  end

  def publish
    find_rating.publish!
    flash[:notice] = "Rating published"
    redirect_to ratings_path
  end

  def unpublish
    find_rating.unpublish!
    flash[:notice] = "Rating unpublished"
    redirect_to ratings_path
  end

  def destroy
    find_rating.destroy
    flash[:notice] = "Rating destroyed"
    redirect_to ratings_path
  end

  private

  def find_rating
    @rating = Rating.find(params[:id])
  end

end
