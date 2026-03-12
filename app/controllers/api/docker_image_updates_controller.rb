# typed: false
# frozen_string_literal: true

module Api
  class DockerImageUpdatesController < ApplicationController
    before_action :require_admin

    def create
      digest = params[:digest]
      SiteSetting.set(DockerImagePollWorker::DIGEST_SETTING_KEY, digest) if digest.present?
      DockerHostImagePullWorker.perform_async
      render json: { status: "queued" }
    end

    private

    def require_admin
      head :forbidden unless api_user&.admin?
    end
  end
end
