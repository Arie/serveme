# typed: strict
# frozen_string_literal: true

class WhitelistTf < ActiveRecord::Base
  extend T::Sig

  validates_presence_of :tf_whitelist_id, :content
  validates_format_of :tf_whitelist_id, with: /\A[a-zA-Z0-9_-]*\z/

  sig { params(tf_whitelist_id: String).returns(T::Boolean) }
  def self.download_and_save_whitelist(tf_whitelist_id)
    tf_whitelist = find_or_initialize_by(tf_whitelist_id: tf_whitelist_id)
    new_content = begin
      whitelist_content(tf_whitelist_id.to_s)
    rescue Faraday::Error
      nil
    end
    if new_content.present?
      tf_whitelist.content = new_content
      tf_whitelist.save!
    else
      tf_whitelist.persisted? && tf_whitelist.content.present?
    end
  end

  sig { params(tf_whitelist_id: String).returns(T.nilable(String)) }
  def self.whitelist_content(tf_whitelist_id)
    if tf_whitelist_id.match(/\A[0-9]*\z/)
      fetch_whitelist("custom_whitelist_#{tf_whitelist_id}")
    else
      fetch_whitelist(tf_whitelist_id)
    end
  end

  sig { params(tf_whitelist_id: String).returns(T.nilable(String)) }
  def self.fetch_whitelist(tf_whitelist_id)
    response = whitelist_connection.get("#{tf_whitelist_id}.txt")
    response.body if response.success?
  end

  sig { returns(Faraday::Connection) }
  def self.whitelist_connection
    Faraday.new(url: "https://whitelist.tf") do |f|
      f.options.timeout = 5
      f.options.open_timeout = 3
    end
  end
end
