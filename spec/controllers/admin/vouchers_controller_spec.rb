# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::VouchersController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:non_admin) { create(:user) }
  let(:product) { create(:product) }
  let(:voucher) { create(:voucher, product: product) }

  describe 'GET #index' do
    context 'when user is admin' do
      before { sign_in admin }

      it 'returns success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns @vouchers' do
        vouchers = create_list(:voucher, 3)
        get :index
        expect(assigns(:vouchers)).to match_array(vouchers)
      end

      it 'includes claimed and unclaimed vouchers' do
        claimed_voucher = create(:voucher, claimed_by: non_admin, claimed_at: Time.current)
        unclaimed_voucher = create(:voucher)
        get :index
        expect(assigns(:vouchers)).to include(claimed_voucher, unclaimed_voucher)
      end
    end

    context 'when user is not admin' do
      before { sign_in non_admin }

      it 'redirects to root' do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is not signed in' do
      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe 'GET #new' do
    context 'when user is admin' do
      before { sign_in admin }

      it 'returns success' do
        get :new
        expect(response).to have_http_status(:success)
      end

      it 'assigns new voucher' do
        get :new
        expect(assigns(:voucher)).to be_a_new(Voucher)
      end

      it 'assigns products' do
        products = create_list(:product, 3)
        get :new
        expect(assigns(:products)).to match_array(products)
      end
    end

    context 'when user is not admin' do
      before { sign_in non_admin }

      it 'redirects to root' do
        get :new
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        product_id: product.id,
        quantity: 5
      }
    end

    context 'when user is admin' do
      before { sign_in admin }

      context 'with valid params' do
        it 'creates new vouchers' do
          expect {
            post :create, params: { voucher: valid_attributes }
          }.to change(Voucher, :count).by(5)
        end

        it 'sets created_by to current admin' do
          post :create, params: { voucher: valid_attributes }
          expect(Voucher.last.created_by).to eq(admin)
        end

        it 'redirects to vouchers index' do
          post :create, params: { voucher: valid_attributes }
          expect(response).to redirect_to(admin_vouchers_path)
        end

        it 'sets success flash message' do
          post :create, params: { voucher: valid_attributes }
          expect(flash[:notice]).to match(/5 vouchers created/)
        end
      end

      context 'with invalid params' do
        it 'does not create vouchers without product' do
          expect {
            post :create, params: { voucher: { quantity: 5 } }
          }.not_to change(Voucher, :count)
        end

        it 'renders new template' do
          post :create, params: { voucher: { quantity: 5 } }
          expect(response).to render_template(:new)
        end
      end
    end

    context 'when user is not admin' do
      before { sign_in non_admin }

      it 'does not create vouchers' do
        expect {
          post :create, params: { voucher: valid_attributes }
        }.not_to change(Voucher, :count)
      end

      it 'redirects to root' do
        post :create, params: { voucher: valid_attributes }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when user is admin' do
      before { sign_in admin }

      context 'when voucher is unclaimed' do
        let!(:unclaimed_voucher) { create(:voucher) }

        it 'destroys the voucher' do
          expect {
            delete :destroy, params: { id: unclaimed_voucher.id }
          }.to change(Voucher, :count).by(-1)
        end

        it 'redirects to vouchers index' do
          delete :destroy, params: { id: unclaimed_voucher.id }
          expect(response).to redirect_to(admin_vouchers_path)
        end
      end

      context 'when voucher is claimed' do
        let!(:claimed_voucher) { create(:voucher, claimed_by: non_admin, claimed_at: Time.current) }

        it 'does not destroy the voucher' do
          expect {
            delete :destroy, params: { id: claimed_voucher.id }
          }.not_to change(Voucher, :count)
        end

        it 'sets error flash message' do
          delete :destroy, params: { id: claimed_voucher.id }
          expect(flash[:alert]).to match(/Cannot delete claimed voucher/)
        end
      end
    end

    context 'when user is not admin' do
      before { sign_in non_admin }

      it 'does not destroy the voucher' do
        voucher
        expect {
          delete :destroy, params: { id: voucher.id }
        }.not_to change(Voucher, :count)
      end

      it 'redirects to root' do
        delete :destroy, params: { id: voucher.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
