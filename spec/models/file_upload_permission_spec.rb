# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FileUploadPermission do
  let(:user) { create(:user) }
  let(:permission) { create(:file_upload_permission, user: user) }

  describe 'validations' do
    it 'requires allowed_paths' do
      permission = build(:file_upload_permission, allowed_paths: [])
      expect(permission).not_to be_valid
      expect(permission.errors[:allowed_paths]).to include("can't be blank")

      permission = build(:file_upload_permission, allowed_paths: [ 'addons/sourcemod/configs/mgemod_spawns.cfg' ])
      expect(permission).to be_valid
    end
  end

  describe '#path_allowed?' do
    context 'with exact path match' do
      before do
        permission.update(allowed_paths: [ 'addons/sourcemod/configs/mgemod_spawns.cfg' ])
      end

      it 'allows exact path match' do
        expect(permission.path_allowed?('addons/sourcemod/configs/mgemod_spawns.cfg')).to be true
      end

      it 'denies non-matching path' do
        expect(permission.path_allowed?('addons/sourcemod/configs/other.cfg')).to be false
      end
    end

    context 'with directory match' do
      before do
        permission.update(allowed_paths: [ 'addons/sourcemod/configs/' ])
      end

      it 'allows files in the directory' do
        expect(permission.path_allowed?('addons/sourcemod/configs/mgemod_spawns.cfg')).to be true
        expect(permission.path_allowed?('addons/sourcemod/configs/other.cfg')).to be true
      end

      it 'denies files outside the directory' do
        expect(permission.path_allowed?('addons/sourcemod/plugins/something.smx')).to be false
      end
    end
  end
end
