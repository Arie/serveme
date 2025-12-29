# typed: true
# frozen_string_literal: true

module Admin
  class VouchersController < ApplicationController
    before_action :require_admin
    before_action :set_voucher, only: [ :destroy ]

    def index
      @pagy, @vouchers = pagy(Voucher.includes(:product, :claimed_by, :created_by)
                         .order(created_at: :desc), limit: 25)
    end

    def new
      @voucher = Voucher.new
      @products = Product.active.order(:name)
    end

    def create
      quantity = voucher_params[:quantity].to_i
      product = Product.find(voucher_params[:product_id])

      if quantity > 0 && quantity <= 100
        vouchers_created = []
        quantity.times do
          voucher = Voucher.generate!(product)
          voucher.update!(created_by: current_user)
          vouchers_created << voucher
        end

        flash[:notice] = "#{quantity} vouchers created successfully"
        redirect_to admin_vouchers_path
      else
        @voucher = Voucher.new
        @products = Product.active.order(:name)
        flash.now[:alert] = "Quantity must be between 1 and 100"
        render :new
      end
    rescue ActiveRecord::RecordNotFound
      @voucher = Voucher.new
      @products = Product.active.order(:name)
      flash.now[:alert] = "Please select a product"
      render :new
    end

    def destroy
      if @voucher.claimed?
        flash[:alert] = "Cannot delete claimed voucher"
      else
        @voucher.destroy
        flash[:notice] = "Voucher deleted successfully"
      end
      redirect_to admin_vouchers_path
    end

    private

    def set_voucher
      @voucher = Voucher.find(params[:id])
    end

    def voucher_params
      params.require(:voucher).permit(:product_id, :quantity)
    end
  end
end
