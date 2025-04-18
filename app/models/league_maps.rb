# typed: true
# frozen_string_literal: true

class LeagueMaps
  extend T::Sig

  attr_accessor :name, :maps

  def initialize(name:, maps:)
    @name = name
    @maps = maps
  end

  sig { returns(T::Array[LeagueMaps]) }
  def self.all
    grouped_league_maps + [ new(name: "All maps", maps: MapUpload.available_maps) ]
  end

  sig { returns(T::Array[LeagueMaps]) }
  def self.grouped_league_maps
    [
      new(name: "ETF2L 6v6", maps: etf2l_sixes_maps.uniq.sort),
      new(name: "ETF2L HL", maps: etf2l_hl_maps.uniq.sort),
      new(name: "ETF2L HL Prem", maps: etf2l_hl_prem_maps.uniq.sort),
      new(name: "ETF2L Ultiduo", maps: etf2l_ultiduo_maps.uniq.sort),
      new(name: "ozfortress Ultiduo", maps: ozfortress_ultiduo_maps.uniq.sort),
      new(name: "ozfortress 6v6", maps: ozfortress_sixes_maps.uniq.sort),
      new(name: "ozfortress HL", maps: ozfortress_hl_maps.uniq.sort),
      new(name: "RGL 6v6", maps: rgl_sixes_maps.uniq.sort),
      new(name: "RGL HL", maps: rgl_hl_maps.uniq.sort),
      new(name: "RGL Pass Time", maps: rgl_pass_time_maps.uniq.sort),
      new(name: "UGC 6v6", maps: ugc_sixes_maps.uniq.sort),
      new(name: "UGC HL", maps: ugc_hl_maps.uniq.sort),
      new(name: "UGC 4v4", maps: ugc_fours_maps.uniq.sort),
      new(name: "UGC Ultiduo", maps: ugc_ultiduo_maps.uniq.sort)
    ]
  end

  def self.all_league_maps
    @all_league_maps ||=
      [
        etf2l_sixes_maps + etf2l_hl_maps + ozfortress_sixes_maps + ozfortress_hl_maps + rgl_sixes_maps + rgl_hl_maps + ugc_sixes_maps + ugc_hl_maps + ugc_fours_maps + ugc_ultiduo_maps
      ].flatten.uniq.sort
  end

  def self.etf2l_sixes_maps
    %w[
      cp_granary_pro_rc16f
      cp_gullywash_f9
      cp_metalworks_f5
      cp_process_f12
      cp_snakewater_final1
      cp_sultry_b8a
      cp_sunshine
      koth_bagel_rc10
      koth_product_final
    ]
  end

  def self.etf2l_hl_maps
    %w[
      cp_steel_f12
      koth_product_final
      koth_proot_b5b
      koth_proplant_v8
      koth_warmtic_f10
      pl_upward_f12
      pl_vigil_rc10
    ]
  end

  def self.etf2l_hl_prem_maps
    %w[
      cp_steel_f12
      koth_ashville_final1
      koth_lakeside_f5
      koth_product_final
      koth_proot_b5b
      pl_upward_f12
      pl_vigil_rc10
    ]
  end

  def self.etf2l_ultiduo_maps
    %w[
      koth_ultiduo_r_b7
      ultiduo_baloo_v2
      ultiduo_grove_b4
      ultiduo_lookout_b1
      ultiduo_cooked_rc2
      ultiduo_process_f10
      ultiduo_babty_f3
    ]
  end

  def self.rgl_sixes_maps
    %w[
      cp_snakewater_final1
      cp_gullywash_f9
      koth_clearcut_b17
      cp_metalworks_f5
      cp_sultry_b8a
      koth_bagel_rc10
      cp_sunshine
      cp_process_f12
      cp_granary_pro_rc17a2
    ]
  end

  def self.rgl_hl_maps
    %w[
      cp_steel_f12
      koth_ashville_final1
      koth_lakeside_f5
      koth_product_final
      pl_swiftwater_final1
      pl_upward_f12
      pl_vigil_rc10
    ]
  end

  def self.rgl_pass_time_maps
    %w[
      pass_arena2_b14b
      pass_ruin_a12_waterless
      pass_boutique_b8c
      pass_plexiglass_b5
      pass_maple_a10
      pass_stadium_rc3a
      pass_stonework_rc2
      pass_torii_a7
    ]
  end

  def self.ugc_hl_maps
    %w[
      cp_steel_f12
      koth_ashville_final1
      koth_proot_b5b
      koth_warmtic_f10
      pl_divulgence_b4b
      pl_swiftwater_final1
      pl_upward_f12
      pl_vigil_rc10
    ]
  end

  def self.ugc_sixes_maps
    %w[
      cp_granary_pro_rc16f
      cp_metalworks_f5
      cp_process_f12
      cp_reckoner
      cp_snakewater_final1
      cp_sunshine
      koth_bagel_rc10
      koth_govan_b6
    ]
  end

  def self.ugc_fours_maps
    %w[
      cp_gravelbine_a11
      cp_warmfrost_rc1
      koth_airfield_b7
      koth_badlands
      koth_bagel_rc10
      koth_cornyard_b4
      koth_jamram_rc2b
      koth_maple_ridge_rc2
    ]
  end

  def self.ugc_ultiduo_maps
    %w[
      ulti_fira_b2a
      ultiduo_baloo_v2
      ultiduo_furnace_b2
      ultiduo_gullywash_b2
      ultiduo_lookout_b1
      ultiduo_noodle
      ultiduo_obsidiian_a10
      ultiduo_spytech_rc4
    ]
  end

  def self.ozfortress_sixes_maps
    %w[
      cp_gullywash_f9
      cp_process_f12
      cp_metalworks_f5
      cp_reckoner
      cp_snakewater_final1
      cp_sunshine
      koth_bagel_rc10
      koth_clearcut_b16a
      koth_product_final
    ]
  end

  def self.ozfortress_hl_maps
    %w[
      cp_steel_f12
      koth_ashville_final1
      koth_product_final
      koth_proot_b6c-alt2
      pl_swiftwater_final1
      pl_upward_f12
      pl_vigil_rc10
      pl_eruption_b14
    ]
  end

  def self.ozfortress_ultiduo_maps
    %w[
      ultiduo_ozf_r
      ultiduo_baloo_v2
      ultiduo_champions_b1
      ultiduo_swine_b06
    ]
  end
end
