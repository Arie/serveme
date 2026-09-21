# typed: true
# frozen_string_literal: true

module Admin
  class MtrTracesController < ApplicationController
    before_action :require_admin

    def index
      @trace = MtrTrace.new(target: params[:target], cycles: MtrTrace::CYCLE_OPTIONS.first)
      load_index
    end

    def show
      @trace = MtrTrace.includes(:runs, :user).find(params[:id])
      @analysis = @trace.analysis
    end

    def create
      sources = Array(params[:source_ids]).filter_map { |id| MtrSource.find_by_id(id.to_s) }
      @trace = MtrTrace.launch(target: params[:target], cycles: params[:cycles], sources: sources, user: current_user)
      return redirect_to(admin_mtr_trace_path(@trace)) if @trace.persisted?

      @selected_source_ids = sources.map(&:id)
      load_index
      render :index, status: :unprocessable_content
    end

    def rerun
      previous = MtrTrace.find(params[:id])
      sources = previous.runs.filter_map(&:source)
      trace = MtrTrace.launch(target: previous.target, cycles: previous.cycles, sources: sources, user: current_user)
      return redirect_to(admin_mtr_trace_path(trace)) if trace.persisted?

      redirect_to admin_mtr_trace_path(previous), alert: trace.errors.full_messages.to_sentence
    end

    private

    def load_index
      @sources = MtrSource.all
      @selected_source_ids ||= []
      @pagy, @traces = pagy(MtrTrace.recent.includes(:runs, :user), limit: 20)
    end
  end
end
