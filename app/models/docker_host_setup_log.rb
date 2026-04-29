# typed: true
# frozen_string_literal: true

class DockerHostSetupLog < ActiveRecord::Base
  belongs_to :docker_host

  validates :step, presence: true
  validates :success, inclusion: { in: [ true, false ] }

  scope :recent, -> { order(created_at: :desc) }

  STEP_LABELS = {
    "install_prerequisites" => "Prerequisites (apt + ufw)",
    "install_docker" => "Docker engine",
    "setup_app_user" => "App user + sudoers",
    "install_compose_services" => "Compose services (Caddy + websocket-echo)"
  }.freeze

  def label
    STEP_LABELS[step] || step
  end
end
