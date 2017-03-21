class WhitelistTf < ActiveRecord::Base

  validates_presence_of :tf_whitelist_id, :content
  validates_numericality_of :tf_whitelist_id, :mininum => 1

  def self.download_and_save_whitelist(tf_whitelist_id)
    tf_whitelist_id = tf_whitelist_id.to_i
    tf_whitelist    = find_or_initialize_by(tf_whitelist_id: tf_whitelist_id)
    tf_whitelist.content = whitelist_content(tf_whitelist_id)
    tf_whitelist.save!
  end

  def self.whitelist_content(tf_whitelist_id)
    whitelist_connection.get("custom_whitelist_#{tf_whitelist_id}.txt").body
  end

  def self.whitelist_connection
    Faraday.new(:url => "http://whitelist.tf")
  end

end
