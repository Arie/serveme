# typed: true
# frozen_string_literal: true

module Admin
  class DockerHostsController < ApplicationController
    before_action :require_admin
    before_action :set_docker_host, only: [ :edit, :update, :destroy ]

    def index
      @docker_hosts = DockerHost.includes(:location).order(:city)
    end

    def new
      @docker_host = DockerHost.new(start_port: 27015, max_containers: 4, active: true)
    end

    def create
      @docker_host = DockerHost.new(docker_host_params)
      if @docker_host.save
        redirect_to admin_docker_hosts_path, notice: "Docker host was successfully created."
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

    private

    def set_docker_host
      @docker_host = DockerHost.find(params[:id])
    end

    def docker_host_params
      params.require(:docker_host).permit(:location_id, :city, :ip, :start_port, :max_containers, :active)
    end
  end
end
