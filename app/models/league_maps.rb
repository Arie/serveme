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
      cp_granary_pro_rc8
      cp_gullywash_f9
      cp_metalworks_f5
      cp_process_f12
      cp_reckoner_rc6
      cp_snakewater_final1
      cp_sunshine
      koth_bagel_rc5
      koth_product_final
    ]
  end

  def self.etf2l_hl_maps
    %w[
      cp_steel_f12
      koth_product_final
      koth_proplant_v8
      pl_badwater_pro_v12
      pl_upward_f10
      pl_vigil_rc9
    ]
  end

  def self.rgl_sixes_maps
    sixes =
      %w[
        cp_gullywash_f9
        cp_metalworks_f5
        cp_process_f12
        cp_snakewater_final1
        cp_sultry_b8
        cp_sunshine
        koth_bagel_rc5
        koth_clearcut_b15d
        koth_product_final
      ]
    sixes_invite =
      %w[
        cp_granary_pro_rc8
        cp_gullywash_f9
        cp_process_f12
        cp_snakewater_final1
        cp_sultry_b8
        cp_sunshine
        koth_bagel_rc5
        koth_product_final
      ]
    sixes + sixes_invite
  end

  def self.rgl_hl_maps
    %w[
      cp_steel_f12
      koth_ashville_final
      koth_product_final
      koth_proot_b5a
      pl_swiftwater_final1
      pl_upward_f10
      pl_vigil_rc9
    ]
  end

  def self.rgl_prolander_maps
    %w[
      cp_steel_f12
      koth_ashville_final
      koth_product_final
      pl_upward_f10
      pl_vigil_rc9
    ]
  end

  def self.ugc_hl_maps
    %w[
      cp_steel_f12
      koth_ashville_final
      koth_cascade
      koth_clearcut_b15d
      koth_product_final
      pl_borneo_f2
      pl_upward_f10
      pl_vigil_rc9
    ]
  end

  def self.ugc_sixes_maps
    %w[
      cp_granary_pro_rc8
      cp_gullywash_f9
      cp_process_f12
      cp_snakewater_final1
      cp_sunshine
      koth_bagel_rc5
      koth_clearcut_b15d
      koth_product_final
    ]
  end

  def self.ugc_fours_maps
    %w[
      cp_warmfrost_rc1
      koth_airfield_b7
      koth_bagel_rc5
      koth_brazil
      koth_highpass
      koth_maple_ridge_rc1
      koth_product_final
      koth_undergrove_rc1
    ]
  end

  def self.ugc_ultiduo_maps
    %w[
      koth_ultiduo_r_b7
      ultiduo_baloo_v2
      ultiduo_champions_legacy_a7
      ultiduo_grove_b4
      ultiduo_gullywash_b2
      ultiduo_lookout_b1
      ultiduo_obsidian_a10
      ultiduo_spytech_rc1
    ]
  end
end
