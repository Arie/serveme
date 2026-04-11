# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::UploadFilesToServersTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("upload_files_to_servers")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema" do
      schema = described_class.input_schema
      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:zip_base64)
      expect(schema[:required]).to include("zip_base64")
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    context "with valid zip" do
      let(:zip_path) { Rails.root.join("spec/fixtures/files/cfg.zip") }
      let(:zip_base64) { Base64.encode64(File.binread(zip_path)) }

      it "creates a FileUpload and queues distribution" do
        create(:server)

        result = tool.execute(zip_base64: zip_base64)

        expect(result[:status]).to eq("uploading")
        expect(result[:file_upload_id]).to be_present
        expect(result[:server_count]).to be >= 1
      end
    end

    context "with invalid base64 data" do
      it "returns an error for non-base64 characters" do
        result = tool.execute(zip_base64: "not!valid@base64###")

        expect(result[:error]).to eq("Invalid base64 data")
      end
    end

    context "with zip exceeding size limit" do
      it "returns an error" do
        stub_const("Mcp::Tools::UploadFilesToServersTool::MAX_ZIP_SIZE", 10)
        zip_data = "x" * 11
        zip_base64 = Base64.strict_encode64(zip_data)

        result = tool.execute(zip_base64: zip_base64)

        expect(result[:error]).to eq("Zip file too large (max 50MB)")
      end
    end

    context "with blank zip_base64" do
      it "returns an error" do
        result = tool.execute(zip_base64: "")

        expect(result[:error]).to include("zip_base64")
      end
    end
  end
end
