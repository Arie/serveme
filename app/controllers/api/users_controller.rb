# frozen_string_literal: true

module Api
  class UsersController < Api::ApplicationController
    def show
      @user = User.find_by_uid!(params[:id].to_i)
    end
  end
end
