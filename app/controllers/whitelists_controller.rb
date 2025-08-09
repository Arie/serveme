# typed: true
# frozen_string_literal: true

class WhitelistsController < ApplicationController
  before_action :require_site_or_league_admin

  def index
    @whitelists = Whitelist.ordered.paginate(page: params[:page], per_page: 50)
  end

  def new
    new_whitelist
    render :new
  end

  def create
    respond_to do |format|
      format.html do
        @whitelist = Whitelist.new(params[:whitelist].permit(:file, :hidden))

        if @whitelist.save
          flash[:notice] = "Whitelist added"
          redirect_to whitelists_path
        else
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    find_whitelist
  end

  def update
    find_whitelist
    @whitelist.update(params[:whitelist].permit(:file, :hidden))
    flash[:notice] = "Whitelist updated"
    redirect_to whitelists_path
  end

  private

  def find_whitelist
    @whitelist = Whitelist.where(id: params[:id]).last
  end

  def new_whitelist
    @whitelist = Whitelist.new
  end
end
