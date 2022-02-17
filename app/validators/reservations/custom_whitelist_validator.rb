# frozen_string_literal: true

module Reservations
  class CustomWhitelistValidator < ActiveModel::Validator
    def validate(record)
      return unless record.custom_whitelist_id.present? && record.custom_whitelist_id_changed?

      if record.custom_whitelist_id.match(/\A[a-zA-Z0-9_-]*\z/)
        try_to_download_custom_whitelist(record)
      else
        record.errors.add(:custom_whitelist_id, "invalid whitelist: \"#{record.custom_whitelist_id}\"")
      end
    end

    private

    def try_to_download_custom_whitelist(record)
      WhitelistTf.download_and_save_whitelist(record.custom_whitelist_id)
    rescue ActiveRecord::RecordInvalid, Faraday::ClientError
      record.errors.add(:custom_whitelist_id, "couldn't download the custom whitelist: \"#{record.custom_whitelist_id}\"")
    end
  end
end
