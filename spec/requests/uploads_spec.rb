# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Zip downloads", type: :request do
  let(:reservation) { create(:reservation) }
  let(:zip_path) { reservation.local_zipfile_path }

  before do
    FileUtils.mkdir_p(zip_path.dirname)
    File.write(zip_path, "zip contents")
  end

  after { FileUtils.rm_f(zip_path) }

  it "does not serve a zip on disk to anonymous visitors" do
    get "/uploads/#{reservation.zipfile_name}"

    expect(response).to have_http_status(:redirect)
    expect(response.body).not_to include("zip contents")
  end
end
