class VouchersController < ApplicationController

  skip_before_filter :block_users_with_expired_reservations

  def new
    @voucher = Voucher.find_by_code(params[:code]) if params[:code]
    if @voucher
      if @voucher.claimed?
        flash.now[:alert] = "This code has already been used"
      end
    else
      @voucher = Voucher.new
    end
  end

  def create
    code = params.require(:voucher).require(:code)
    @voucher = Voucher.unclaimed.find_by_code(code)
    if @voucher
      @voucher.claim!(current_user)
      flash.now[:notice] = "Code activated: #{@voucher.product.name}"
      redirect_to root_path
    else
      flash.now[:alert] = "Invalid code or already used"
      @voucher = Voucher.new
      render :new
    end
  end

end
