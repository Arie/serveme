module Reservations
  class CustomWhitelistValidator < ActiveModel::Validator

    def validate(record)
      custom_whitelist_id = record.custom_whitelist_id
      if custom_whitelist_id.present? && record.custom_whitelist_id_changed?
        if custom_whitelist_id.match(/\A[a-zA-Z0-9_-]*\z/)
          begin
            WhitelistTf.download_and_save_whitelist(custom_whitelist_id)
          rescue ActiveRecord::RecordInvalid, Faraday::Error::ClientError
            record.errors.add(:custom_whitelist_id, "couldn't download the custom whitelist: \"#{custom_whitelist_id}\"")
          end
        else
          record.errors.add(:custom_whitelist_id, "invalid whitelist: \"#{custom_whitelist_id}\"")
        end
      end
    end

  end
end
