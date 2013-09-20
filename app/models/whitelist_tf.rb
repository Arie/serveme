class WhitelistTf < ActiveRecord::Base

  attr_accessible :tf_whitelist_id, :content
  validates_presence_of :tf_whitelist_id, :content
  validates_numericality_of :tf_whitelist_id, :mininum => 1

  def self.find_or_download(tf_whitelist_id)
    tf_whitelist_id = tf_whitelist_id.to_i
    find_by_tf_whitelist_id(tf_whitelist_id) || download_and_save_whitelist(tf_whitelist_id)
  end

  def self.download_and_save_whitelist(tf_whitelist_id)
    create!(:tf_whitelist_id => tf_whitelist_id, :content => whitelist_content(tf_whitelist_id))
  end

  def self.whitelist_content(tf_whitelist_id)
    whitelist_connection.get("custom_whitelist_#{tf_whitelist_id}.txt").body
  end

  def self.whitelist_connection
    Faraday.new(:url => "http://whitelist.tf")
  end

end
