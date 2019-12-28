# frozen_string_literal: true
require 'zip'

class MapUpload < ActiveRecord::Base
  BLACKLIST = ["pl_badwater_pro_v8.bsp", "cp_warpath.bsp"]
  belongs_to :user
  attr_accessor :maps

  validates_presence_of :user_id
  validate :validate_not_already_present,   :unless => :archive?
  validate :validate_file_is_a_bsp,         :unless => :archive?
  validate :validate_not_blacklisted,       :unless => :archive?

  after_create :process_maps
  after_create :remove_uploaded_file,       :if => :zip?

  mount_uploader :file, MapUploader

  def process_maps
    @maps = []
    if archive?
      @maps = extract_archive
    else
      @maps << file.file.filename
    end
    bzip2_uploaded_maps unless bz2?
    upload_maps_to_servers
  end

  def self.available_maps
    Rails.cache.fetch "maps_#{last.try(:created_at).to_i}", :expires_in => 1.day do
      map_filematcher = File.join(MAPS_DIR, "*.bsp")
      map_filenames = Dir.glob(map_filematcher)
      map_filenames.map { |filename| filename.match(/.*\/(.*)\.bsp/)[1] }.sort
    end
  end

  def self.available_cloud_maps
    ['achievement_duel', 'bball_tf_v2', 'cp_alloy_rc3',
    'cp_badlands', 'cp_badlands_pro', 'cp_dustbowl', 'cp_granary_pro',
    'cp_granary_pro_rc10', 'cp_granary_pro_rc8', 'cp_granary_pro_rc9', 'cp_gullywash',
    'cp_gullywash_final1', 'cp_gullywash_pro', 'cp_kalinka_rc5', 'cp_logjam_rc10a',
    'cp_logjam_rc11', 'cp_logjam_rc10', 'cp_logjam_rc8', 'cp_logjam_rc9', 'cp_metalworks_rc7',
    'cp_mojave_b2', 'cp_orange_x3', 'cp_process_a1', 'cp_process_final',
    'cp_prolands_b5', 'cp_prolands_b6', 'cp_prolands_rc1', 'cp_prolands_rc2p', 'cp_prolands_rc2t',
    'cp_propaganda_b15', 'cp_propaganda_b16', 'cp_reckoner_rc2', 'cp_snakewater', 'cp_snakewater_final1',
    'cp_snakewater_u14', 'cp_snakewater_u18', 'cp_steel', 'cp_sunshine', 'cp_sunshine_event',
    'cp_warmfrost_rc1', 'ctf_2fort', 'ctf_ballin_sky', 'ctf_bball2',
    'ctf_bball_sweethills_v1', 'ctf_turbine', 'Dm_glory', 'dm_store', 'gg200_orange_x3',
    'itemtest', 'jump_academy2_rc7', 'jump_beef', 'jump_bomb', 'jump_cube_b6', 'jump_home_v2',
    'jump_iT_final', 'jump_QuBA', 'koth_airfield_b7', 'koth_ashville_rc1', 'koth_badlands',
    'koth_brazil_rc1', 'koth_cascade_rc1a', 'koth_clearcut_b9a', 'koth_clearcut_b10a', 'koth_coalplant_b7',
    'koth_coalplant_b8', 'koth_harvest', 'koth_harvest_final', 'koth_highpass',
    'koth_isla_b14', 'koth_lakeside_final', 'koth_maple_ridge_b6', 'koth_nucleus',
    'koth_ordinance_b5', 'koth_product_pro_rc1', 'koth_product_rc8', 'koth_product_rc9',
    'koth_product_rcx', 'koth_product_ugc', 'koth_pro_viaduct_rc4', 'koth_stallone_b2',
    'koth_ultiduo', 'koth_ultiduo_r_b7', 'koth_viaduct_pro7', 'koth_warmtic_b6',
    'koth_warmtic_rc4', 'mge_chillypunch_final4', 'mge_oihguv_sucks_a12', 'mge_training_v8_beta4b',
    'pl_badwater', 'pl_badwater_pro_rc12', 'pl_badwater_pro_v12', 'pl_badwater_pro_v9',
    'pl_barnblitz_pro6', 'pl_borneo', 'pl_downword', 'plr_hightower',
    'pl_summercoast_rc4', 'pl_swiftwater_final1', 'pl_upward_abandoned', 'pl_upward',
    'pl_vigil_rc4', 'tr_walkway_rc2', 'ultiduo_baloo', 'ultiduo_baloo_v2',
    'ultiduo_grove_b4', 'ultiduo_gullywash_b2', 'ultiduo_seclusion_b3']
  end

  def validate_not_already_present
    if file.filename && self.class.map_exists?(file.filename)
      errors.add(:file, "already available")
    end
  end

  def validate_file_is_a_bsp
    if file.file && File.open(file.file.file).read(4) != "VBSP"
      errors.add(:file, "not a map (bsp) file")
    end
  end

  def validate_not_blacklisted
    if file.filename && self.class.blacklisted?(file.filename)
      errors.add(:file, "map blacklisted, causes server instability")
    end
  end

  def maps_with_full_path
    maps.collect do |map|
      File.join(MAPS_DIR, map)
    end
  end

  def upload_maps_to_servers
    if maps_with_full_path.any?
      UploadFilesToServersWorker.perform_async(files: maps_with_full_path,
                                              destination: "maps",
                                              overwrite: false)
    end
  end

  def self.map_exists?(filename)
    if File.exists?(File.join(MAPS_DIR, filename.split("/").last))
      Rails.logger.info "File #{filename} already exists in #{MAPS_DIR}"
      true
    end
  end

  def self.blacklisted?(filename)
    target_filename = filename.match(/(^.*\.bsp)/)[1]
    BLACKLIST.include?(target_filename)
  end

  def bzip2_uploaded_maps
    maps_with_full_path.each do |map_with_path|
      Rails.logger.info "Bzipping #{map_with_path}"
      `bzip2 -k #{map_with_path}`
    end
  end

  def extract_archive
    send("extract_#{archive_type}")
  end

  def extract_zip
    maps = []
    Zip::File.foreach(file.file.file) do |zipped_file|
      filename = File.basename(zipped_file.name)
      if filename.match(/^.*\.bsp$/) && !filename.match(/__MACOSX/) && !self.class.map_exists?(filename) && !self.class.blacklisted?(filename)
        Rails.logger.info "Extracting #{filename} from #{file.file.file} upload ##{self.id} (ZIP)"
        zipped_file.extract(File.join(MAPS_DIR, filename)) { false }
        maps << filename
      end
    end
    maps
  end

  def remove_uploaded_file
    Rails.logger.info "Removing uploaded zip #{file.file.file}"
    FileUtils.rm(file.file.file)
  end


  def extract_bz2
    filename        = file.file.filename
    source_file     = file.file.file
    target_filename = filename.match(/(^.*\.bsp)\.bz2/)[1]
    maps = []

    if !self.class.map_exists?(target_filename) && !self.class.blacklisted?(target_filename)
      Rails.logger.info "Extracting #{target_filename} from #{filename} upload ##{self.id} (BZ2)"
      data  = RBzip2.default_adapter::Decompressor.new(File.new(source_file)).read

      Rails.logger.info "Writing uncompressed #{target_filename}"
      File.open(File.join(MAPS_DIR, target_filename), "wb+") { |f| f.write(data) }
      maps << target_filename
    end
    maps
  end

  def archive_type
    case file.to_s
    when /^.*\.zip$/
      :zip
    when /^.*\.bsp\.bz2$/
      :bz2
    else
      nil
    end
  end

  def archive?
    archive_type.present?
  end

  def zip?
    archive_type == :zip
  end

  def bz2?
    archive_type == :bz2
  end

end
