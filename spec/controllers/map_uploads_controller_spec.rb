# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe MapUploadsController do
  include ActionDispatch::TestProcess::FixtureFile

  render_views

  let(:user) { create :user }
  let(:donator) do
    u = create :user
    u.groups << Group.donator_group
    u
  end
  let(:admin) do
    u = create :user
    u.groups << Group.admin_group
    u
  end

  describe '#index' do
    let(:mock_bucket_objects) do
      [
        {
          key: 'maps/cp_badlands.bsp',
          map_name: 'cp_badlands',
          size: 1024000,
          uploader: nil,
          upload_date: nil
        }
      ]
    end

    before do
      allow(MapUpload).to receive(:bucket_objects).and_return(mock_bucket_objects)
      allow(MapUpload).to receive(:map_statistics).and_return({})
    end

    it 'renders the index page for anonymous users' do
      get :index
      expect(response).to be_successful
      expect(response).to render_template(:index)
      expect(response.body).to include('cp_badlands')
    end

    it 'raises UnknownFormat for JSON requests' do
      expect do
        get :index, format: :json
      end.to raise_error(ActionController::UnknownFormat)
    end

    it 'redirects admins to the admin maps page, keeping the sort order' do
      sign_in admin
      get :index, params: { sort_by: 'size' }
      expect(response).to redirect_to('/admin/maps?sort_by=size')
    end

    context 'sorting' do
      let(:mock_bucket_objects) do
        [
          { map_name: 'pl_upward', size: 300 },
          { map_name: 'cp_badlands', size: 100 },
          { map_name: 'koth_nosize', size: nil },
          { map_name: 'ctf_2fort', size: 200 },
          { map_name: 'cp_unplayed', size: 50 }
        ]
      end
      let(:statistics) do
        {
          'pl_upward' => { times_played: 5, first_played: Time.utc(2020, 1, 1), last_played: Time.utc(2024, 1, 1) },
          'cp_badlands' => { times_played: 50, first_played: Time.utc(2015, 1, 1), last_played: Time.utc(2025, 1, 1) },
          'koth_nosize' => { times_played: 1, first_played: Time.utc(2023, 1, 1), last_played: Time.utc(2023, 1, 1) },
          'ctf_2fort' => { times_played: 20, first_played: Time.utc(2018, 1, 1), last_played: Time.utc(2022, 1, 1) }
        }
      end

      before do
        allow(MapUpload).to receive(:map_statistics).and_return(statistics)
      end

      let(:sorted_names) { -> { assigns(:bucket_objects).map { |o| o[:map_name] } } }

      it 'sorts by map name ascending by default' do
        get :index
        expect(sorted_names.call).to eq %w[cp_badlands cp_unplayed ctf_2fort koth_nosize pl_upward]
      end

      it 'falls back to map name for unknown sort keys' do
        get :index, params: { sort_by: 'bogus' }
        expect(sorted_names.call).to eq %w[cp_badlands cp_unplayed ctf_2fort koth_nosize pl_upward]
      end

      it 'sorts by size descending' do
        get :index, params: { sort_by: 'size' }
        expect(sorted_names.call).to eq %w[pl_upward ctf_2fort cp_badlands cp_unplayed koth_nosize]
      end

      it 'sorts by times played descending with unplayed maps last' do
        get :index, params: { sort_by: 'times-played' }
        expect(sorted_names.call).to eq %w[cp_badlands ctf_2fort pl_upward koth_nosize cp_unplayed]
      end

      it 'sorts by last played descending with unplayed maps last' do
        get :index, params: { sort_by: 'last-played' }
        expect(sorted_names.call).to eq %w[cp_badlands pl_upward koth_nosize ctf_2fort cp_unplayed]
      end

      it 'sorts by first played ascending with unplayed maps last' do
        get :index, params: { sort_by: 'first-played' }
        expect(sorted_names.call).to eq %w[cp_badlands ctf_2fort pl_upward koth_nosize cp_unplayed]
      end
    end
  end

  describe '#new' do
    it 'redirects non-donators to root with an alert' do
      sign_in user
      get :new
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq 'Only donators can do that...'
    end

    it 'renders the upload form for donators' do
      sign_in donator
      get :new
      expect(response).to be_successful
      expect(assigns(:map_upload)).to be_a_new(MapUpload)
    end
  end

  describe '#create' do
    before { sign_in donator }

    it 're-renders the form without creating anything when no map_upload params are given' do
      expect { post :create }.not_to change(MapUpload, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:new)
    end

    it 'redirects with a notice when the upload saves' do
      allow_any_instance_of(MapUpload).to receive(:save).and_return(true)

      post :create, params: { map_upload: { file: file_fixture_upload('cp_granlands123.bsp', 'application/octet-stream') } }

      expect(response).to redirect_to(new_map_upload_path)
      expect(flash[:notice]).to eq 'Map upload succeeded. It can take a few minutes for it to get synced to all servers.'
      expect(assigns(:map_upload).user).to eq donator
    end

    it 'renders new with 422 when the file is not a bsp' do
      allow(ActiveStorage::Blob.service).to receive(:exist?).and_return(false)

      expect do
        post :create, params: { map_upload: { file: file_fixture_upload('cfg.zip', 'application/octet-stream') } }
      end.not_to change(MapUpload, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:new)
      expect(assigns(:map_upload).errors.full_messages).to include('File not a map (bsp) file')
    end

    it 'rejects map names with characters that are unsafe on the servers' do
      allow(ActiveStorage::Blob.service).to receive(:exist?).and_return(false)
      upload = Rack::Test::UploadedFile.new(file_fixture('cp_granlands123.bsp'), 'application/octet-stream', original_filename: "cp_x'$(id).bsp")

      expect do
        post :create, params: { map_upload: { file: upload } }
      end.not_to change(MapUpload, :count)

      expect(assigns(:map_upload).errors.full_messages.join).to include('name may only contain')
    end
  end

  describe '#presigned_url' do
    let(:service) { double('ActiveStorage service') }
    let(:json) { JSON.parse(response.body) }

    before do
      sign_in donator
      allow(ActiveStorage::Blob).to receive(:service).and_return(service)
      allow(service).to receive(:exist?).and_return(false)
    end

    it 'redirects non-donators' do
      sign_in user
      post :presigned_url, params: { filename: 'cp_new.bsp' }
      expect(response).to redirect_to(root_path)
    end

    it 'rejects a missing filename' do
      post :presigned_url
      expect(response).to have_http_status(:bad_request)
      expect(json).to eq('error' => 'Missing filename')
    end

    it 'rejects non-bsp files' do
      post :presigned_url, params: { filename: 'cp_new.zip' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq('error' => 'Only .bsp files are allowed')
    end

    it 'rejects filenames with illegal characters' do
      post :presigned_url, params: { filename: '../etc/passwd.bsp' }
      expect(response).to have_http_status(:bad_request)
      expect(json).to eq('error' => 'Invalid filename')
    end

    it 'rejects maps that already exist in the bucket' do
      allow(service).to receive(:exist?).with('maps/cp_existing.bsp').and_return(true)
      post :presigned_url, params: { filename: 'cp_existing.bsp' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq('error' => 'Map already exists')
    end

    it 'rejects blacklisted game types' do
      post :presigned_url, params: { filename: 'mvm_decoy.bsp' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq('error' => 'Game type not allowed')
    end

    context 'with an S3 client' do
      let(:s3_object) { double('S3 object') }
      let(:bucket) { double('S3 bucket', object: s3_object) }
      let(:s3_resource) { double('S3 resource', client: double('S3 client'), bucket: bucket) }

      before do
        allow(service).to receive(:client).and_return(s3_resource)
      end

      it 'returns a presigned PUT url for a quarantine key, not for maps/' do
        allow(s3_object).to receive(:presigned_url).and_return('https://r2.example/pending?sig=abc')

        freeze_time do
          post :presigned_url, params: { filename: 'cp_new.bsp', content_type: 'text/html' }

          expect(response).to be_successful
          expect(json['url']).to eq('https://r2.example/pending?sig=abc')
          expect(json['method']).to eq('PUT')
          expect(json['expires_at']).to eq(15.minutes.from_now.iso8601)
        end
        expect(MapUpload.pending_key_for?(json['key'], 'cp_new.bsp')).to be true
        expect(bucket).to have_received(:object).with(json['key'])
        expect(s3_object).to have_received(:presigned_url).with(
          :put,
          expires_in: 900,
          content_type: 'application/octet-stream',
          whitelist_headers: [ 'content-type', 'x-amz-content-sha256' ]
        )
      end

      it 'returns a 500 and logs when presigning fails' do
        allow(s3_object).to receive(:presigned_url).and_raise(StandardError, 'boom')
        allow(Rails.logger).to receive(:error)

        post :presigned_url, params: { filename: 'cp_new.bsp' }

        expect(response).to have_http_status(:internal_server_error)
        expect(json).to eq('error' => 'Failed to generate upload URL')
        expect(Rails.logger).to have_received(:error).with('Error generating presigned URL: boom')
      end
    end
  end

  describe '#complete' do
    let(:json) { JSON.parse(response.body) }
    let(:pending_key) { MapUpload.pending_key_for('cp_new.bsp') }

    before do
      sign_in donator
      Rails.cache.write("pending_map_upload:#{pending_key}", donator.id)
    end

    it 'rejects missing parameters' do
      post :complete, params: { key: pending_key }
      expect(response).to have_http_status(:bad_request)
      expect(json).to eq('error' => 'Missing parameters')
    end

    it 'rejects a key that does not match the filename' do
      expect(MapUpload).not_to receive(:create_from_direct_upload)
      post :complete, params: { key: pending_key, filename: 'cp_other.bsp' }
      expect(response).to have_http_status(:bad_request)
      expect(json).to eq('error' => 'Key does not match filename')
    end

    it 'rejects keys directly in maps/' do
      expect(MapUpload).not_to receive(:create_from_direct_upload)
      post :complete, params: { key: 'maps/cp_new.bsp', filename: 'cp_new.bsp' }
      expect(response).to have_http_status(:bad_request)
    end

    it "rejects another user's pending upload" do
      Rails.cache.write("pending_map_upload:#{pending_key}", donator.id + 1)
      expect(MapUpload).not_to receive(:create_from_direct_upload)
      post :complete, params: { key: pending_key, filename: 'cp_new.bsp' }
      expect(response).to have_http_status(:bad_request)
      expect(json).to eq('error' => 'Unknown upload')
    end

    it 'creates the map upload for the current user' do
      allow(MapUpload).to receive(:create_from_direct_upload).and_return(success: true)

      post :complete, params: { key: pending_key, filename: 'cp_new.bsp' }

      expect(response).to be_successful
      expect(json).to eq('message' => 'Upload completed successfully')
      expect(MapUpload).to have_received(:create_from_direct_upload).with(user: donator, pending_key: pending_key, filename: 'cp_new.bsp')
      expect(Rails.cache.read("pending_map_upload:#{pending_key}")).to be_nil
    end

    it 'returns the error when the direct upload fails' do
      allow(MapUpload).to receive(:create_from_direct_upload).and_return(success: false, error: 'File not a map')

      post :complete, params: { key: pending_key, filename: 'cp_new.bsp' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq('error' => 'File not a map')
    end
  end

  describe '#destroy' do
    it 'redirects non-admins to root without deleting' do
      sign_in donator
      expect(MapUpload).not_to receive(:delete_bucket_object)
      delete :destroy, params: { id: 'cp_badlands' }
      expect(response).to redirect_to(root_path)
    end

    context 'as admin' do
      before do
        sign_in admin
        allow(MapUpload).to receive(:bucket_objects).and_return([])
        allow(MapUpload).to receive(:map_statistics).and_return({})
      end

      it 'deletes the map and redirects with a notice' do
        allow(MapUpload).to receive(:delete_bucket_object)

        delete :destroy, params: { id: 'cp_badlands' }

        expect(MapUpload).to have_received(:delete_bucket_object).with('cp_badlands')
        expect(response).to redirect_to(maps_path)
        expect(flash[:notice]).to eq 'Map cp_badlands deleted'
      end

      it 'shows an alert for invalid map names' do
        allow(MapUpload).to receive(:delete_bucket_object).and_raise(ArgumentError)

        delete :destroy, params: { id: 'bad name' }

        expect(response).to redirect_to(maps_path)
        expect(flash[:alert]).to eq 'Invalid map name'
        expect(flash[:notice]).to be_nil
      end
    end
  end
end
