# frozen_string_literal: true

class LeagueMaps
  attr_accessor :name, :maps

  def initialize(name:, maps:)
    @name = name
    @maps = maps
  end

  def self.all
    [
      new(name: 'ETF2L 6v6', maps: etf2l_sixes_maps.uniq.sort),
      new(name: 'ETF2L HL', maps: etf2l_hl_maps.uniq.sort),
      new(name: 'RGL 6v6', maps: rgl_sixes_maps.uniq.sort),
      new(name: 'RGL HL', maps: rgl_hl_maps.uniq.sort),
      new(name: 'RGL Prolander', maps: rgl_prolander_maps.uniq.sort),
      new(name: 'UGC 6v6', maps: ugc_sixes_maps.uniq.sort),
      new(name: 'UGC HL', maps: ugc_hl_maps.uniq.sort),
      new(name: 'UGC 4v4', maps: ugc_fours_maps.uniq.sort),
      new(name: 'UGC Ultiduo', maps: ugc_ultiduo_maps.uniq.sort),
      new(name: 'All maps', maps: MapUpload.available_maps)
    ]
  end

  def self.etf2l_sixes_maps
    %w[
      cp_process_f11
      cp_gullywash_f9
      cp_snakewater_final1
      koth_product_final
      cp_sunshine
      koth_bagel_rc5
      cp_reckoner_rc6
    ]
  end

  def self.etf2l_hl_maps
    %w[
      pl_upward_f10
      pl_vigil_rc9
      cp_steel_f11
      koth_product_final
      koth_proplant_v8
      pl_badwater_pro_v12
    ]
  end

  def self.rgl_sixes_maps
    sixes =
      %w[
        cp_gullywash_f9
        koth_bagel_rc5
        cp_metalworks_f4
        cp_snakewater_final1
        koth_product_final
        cp_process_f11
        koth_clearcut_b15d
        cp_sunshine
      ]
    sixes_invite =
      %w[
        cp_gullywash_f9
        koth_bagel_rc5
        cp_metalworks_f4
        cp_snakewater_final1
        koth_product_final
        cp_process_f11
        cp_granary_pro_rc8
        cp_sunshine
      ]
    sixes + sixes_invite
  end

  def self.rgl_hl_maps
    %w[
      pl_upward_f10
      koth_ashville_final
      pl_vigil_rc9
      koth_proot_b4b
      pl_swiftwater_final1
      koth_product_final
      cp_steel_f12
    ]
  end

  def self.rgl_prolander_maps
    %w[
      koth_product_final
      koth_ashville_rc2d
      pl_vigil_rc9
      pl_upward_f5
      cp_steel_f8
    ]
  end

  def self.ugc_hl_maps
    %w[
      koth_ashville_final
      pl_borneo_f2
      koth_cascade
      pl_vigil_rc9
      koth_product_final
      pl_upward_f10
      koth_clearcut_b15d
      cp_steel_f12
    ]
  end

  def self.ugc_sixes_maps
    %w[
      cp_granary_pro_rc8
      koth_bagel_rc5
      cp_gullywash_f9
      koth_product_final
      cp_sunshine
      koth_clearcut_b15d
      cp_process_f11
      cp_snakewater_final1
    ]
  end

  def self.ugc_fours_maps
    %w[
      koth_maple_ridge_rc1
      koth_highpass_rc1a
      koth_brazil_rc3
      koth_product_final
      cp_warmfrost_rc1
      koth_bagel_rc5
      koth_undergrove_rc1
      koth_airfield_b7
    ]
  end

  def self.ugc_ultiduo_maps
    %w[
      koth_ultiduo_r_b7
      ultiduo_obsidian_a10
      ultiduo_spytech_rc1
      ultiduo_grove_b4
      ultiduo_baloo_v2
      ultiduo_lookout_b1
      ultiduo_champions_legacy_a7
      ultiduo_gullywash_b2
    ]
  end
end
