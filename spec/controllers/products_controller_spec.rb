# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductsController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:non_admin) { create(:user) }
  let(:product) { create(:product) }

  describe 'GET #index' do
    context 'when user is admin' do
      before { sign_in admin }

      it 'assigns @products' do
        products = create_list(:product, 3)
        get :index
        expect(response).to have_http_status(:success)
        expect(assigns(:products)).to match_array(products)
      end
    end
  end

  describe 'GET #new' do
    context 'when user is admin' do
      before { sign_in admin }

      it 'assigns new product' do
        get :new
        expect(response).to have_http_status(:success)
        expect(assigns(:product)).to be_a_new(Product)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        name: 'Premium Plan',
        price: 9.99,
        currency: 'USD',
        days: 30,
        active: true
      }
    end

    context 'when user is admin' do
      before { sign_in admin }

      context 'with valid params' do
        it 'creates a new Product' do
          expect {
            post :create, params: { product: valid_attributes }
          }.to change(Product, :count).by(1)

          expect(response).to redirect_to(products_path)
        end
      end
    end
  end

  describe 'GET #edit' do
    context 'when user is admin' do
      before { sign_in admin }

      it 'returns success' do
        get :edit, params: { id: product.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:product)).to eq(product)
      end
    end
  end

  describe 'PATCH #update' do
    let(:new_attributes) do
      {
        name: 'Updated Plan',
        price: 19.99
      }
    end

    context 'when user is admin' do
      before { sign_in admin }

      context 'with valid params' do
        it 'updates the product' do
          patch :update, params: { id: product.id, product: new_attributes }
          product.reload
          expect(product.name).to eq('Updated Plan')
          expect(product.price).to eq(19.99)
          expect(response).to redirect_to(products_path)
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when user is admin' do
      before { sign_in admin }

      it 'destroys the product' do
        product
        expect {
          delete :destroy, params: { id: product.id }
        }.to change(Product, :count).by(-1)
        expect(response).to redirect_to(products_path)
      end
    end
  end
end
