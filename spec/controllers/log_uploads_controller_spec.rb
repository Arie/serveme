# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LogUploadsController do
  before do
    @user         = create :user
    @reservation  = create :reservation, user: @user
  end

  context 'as a normal user' do
    before do
      sign_in @user
    end

    describe '#new' do
      it 'assigns the log_upload variable and links it to the reservation' do
        get :new, params: { reservation_id: @reservation.id }
        assigns(:log_upload).reservation.should eql @reservation
      end

      it 'finds the file from the params' do
        subject.stub(logs: [{ file_name: 'foo.log' }])
        get :new, params: { reservation_id: @reservation.id, file_name: 'foo.log' }
        assigns(:log_upload).file_name.should eql 'foo.log'
      end

      it "sets the file to nil if it wasn't found" do
        subject.stub(logs: [{ file_name: 'bar.log' }])
        get :new, params: { reservation_id: @reservation.id, file_name: 'foo.log' }
        assigns(:log_upload).file_name.should eql nil
      end
    end

    describe '#create' do
      before do
        subject.stub(:link_log_upload_to_reservation)
        @upload = as_null_object
        @upload.should_receive(:file_name=)
      end

      context 'successful save' do
        it 'starts the upload to logs.tf' do
          @upload.should_receive(:save).and_return(true)
          subject.should_receive(:find_log_file).with(anything).and_return(file_name: 'foo.log')
          @upload.should_receive(:upload)
          LogUpload.should_receive(:new).with(anything).and_return(@upload)
          post :create, params: { reservation_id: @reservation.id, log_upload: { file_name: 'foo' } }
        end
      end

      context 'unsuccesful save' do
        it 'doesnt upload' do
          @upload.should_receive(:save).and_return(false)
          @upload.should_not_receive(:upload)
          LogUpload.should_receive(:new).with(anything).and_return(@upload)
          post :create, params: { reservation_id: @reservation.id, log_upload: { file_name: 'bar' } }
        end
      end
    end

    describe '#index' do
      it 'assigns the logs variable' do
        logs = double
        subject.stub(logs: logs)

        get :index, params: { reservation_id: @reservation.id }
        assigns(:logs).should eql logs
      end

      it 'assigns the log_uploads variable' do
        log_uploads = double
        subject.stub(log_uploads: log_uploads)

        get :index, params: { reservation_id: @reservation.id }
        assigns(:log_uploads).should eql log_uploads
      end
    end

    describe '#show_log' do
      it 'assigns the log_file variable' do
        log = double.as_null_object
        subject.stub(logs: [{ file_name: 'foo.log', file_name_and_path: 'bar.log' }])
        File.should_receive(:read).with('bar.log').and_return(log)
        get :show_log, params: { reservation_id: @reservation.id, file_name: 'foo.log' }
      end
    end
  end

  context 'as an admin' do
    before do
      @admin = create(:user)
      @admin.groups << Group.admin_group
      sign_in @admin
    end

    describe '#index' do
      it "shows me the logs even though it's not my reservation" do
        get :index, params: { reservation_id: @reservation.id }
        response.should be_successful
      end
    end
  end
end
