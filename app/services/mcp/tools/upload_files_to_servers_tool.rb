# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class UploadFilesToServersTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "upload_files_to_servers"
      end

      sig { override.returns(String) }
      def self.description
        "Upload a zip file to all active game servers. The zip should be structured relative to the TF2 'tf' directory. " \
        "For example, a zip containing 'addons/sourcemod/plugins/myplugin.smx' will place that file in " \
        "'tf/addons/sourcemod/plugins/myplugin.smx' on each server. " \
        "Files are distributed asynchronously via background workers."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            zip_base64: {
              type: "string",
              description: "Base64-encoded zip file contents"
            },
            description: {
              type: "string",
              description: "Optional description of what the upload contains"
            }
          },
          required: [ "zip_base64" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        zip_base64 = params[:zip_base64]
        return { error: "zip_base64 is required" } if zip_base64.blank?

        zip_data = Base64.decode64(zip_base64)
        return { error: "Invalid base64 data" } if zip_data.blank?

        tmp_zip = Tempfile.new([ "mcp_upload", ".zip" ], binmode: true)
        tmp_zip.write(zip_data)
        tmp_zip.rewind

        file_upload = FileUpload.new(user: user)
        file_upload.file = T.unsafe(tmp_zip)
        unless file_upload.save
          tmp_zip.close!
          return { error: "Failed to save upload: #{file_upload.errors.full_messages.join(', ')}" }
        end

        servers = file_upload.process_file
        tmp_zip.close!

        {
          status: "uploading",
          file_upload_id: file_upload.id,
          server_count: servers.size,
          message: "Upload queued for distribution to #{servers.size} servers"
        }
      end
    end
  end
end
