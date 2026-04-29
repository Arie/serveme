# typed: true
# frozen_string_literal: true

module Admin
  class DockerHostsController < ApplicationController
    before_action :require_admin
    before_action :set_docker_host, only: [ :edit, :update, :destroy, :setup, :run_setup_step ]

    SETUP_STEPS = %w[create_vm dns ssh provision ssl pull_image].freeze

    def index
      @docker_hosts = DockerHost.includes(:location).order(:city)
    end

    def new
      @docker_host = DockerHost.new(start_port: 27015, max_containers: 4, active: false)
    end

    def create
      @docker_host = DockerHost.new(docker_host_params)
      if @docker_host.save
        redirect_to setup_admin_docker_host_path(@docker_host), notice: "Docker host created. Follow the setup steps below."
      else
        render :new
      end
    end

    def edit; end

    def update
      if @docker_host.update(docker_host_params)
        redirect_to admin_docker_hosts_path, notice: "Docker host was successfully updated."
      else
        render :edit
      end
    end

    def destroy
      @docker_host.update(active: false)
      redirect_to admin_docker_hosts_path, notice: "Docker host was successfully deactivated."
    end

    def setup; end

    def run_setup_step
      step = params[:step]
      unless SETUP_STEPS.include?(step)
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("step-#{step}-result", partial: "admin/docker_hosts/step_result", locals: { step: step, result: { success: false, message: "Unknown step: #{step}" } }) }
        end
        return
      end

      DockerHostSetupStepWorker.perform_async(@docker_host.id, step)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("step-#{step}-result", partial: "admin/docker_hosts/step_running", locals: { step: step }),
            turbo_stream.replace("step-#{step}-controls", partial: "admin/docker_hosts/step_controls", locals: { docker_host: @docker_host, step: step, running: true })
          ]
        end
      end
    end

    private

    def set_docker_host
      @docker_host = DockerHost.find(params[:id])
    end

    def docker_host_params
      params.require(:docker_host).permit(:location_id, :city, :ip, :hostname, :start_port, :max_containers, :active, :provider, :provider_location, :ssh_user, :ssh_port, :latitude, :longitude)
    end
  end
end
