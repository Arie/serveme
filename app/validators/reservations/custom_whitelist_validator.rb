module Reservations
  class CustomWhitelistValidator < ActiveModel::Validator

    def validate(record)
      custom_whitelist_id = record.custom_whitelist_id
      if custom_whitelist_id.present? && record.custom_whitelist_id_changed?
        begin
          WhitelistTf.download_and_save_whitelist(custom_whitelist_id)
        rescue ActiveRecord::RecordInvalid, Faraday::Error::ClientError
          record.errors.add(:custom_whitelist_id, "couldn't download the custom whitelist")
        end
      end
    end

  end
end
