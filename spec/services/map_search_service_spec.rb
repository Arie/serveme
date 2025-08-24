# typed: false

require 'spec_helper'

RSpec.describe MapSearchService do
  let(:available_maps) { [
    'cp_process_f12',
    'cp_process_f11',
    'cp_process_final',
    'cp_gullywash_f9',
    'cp_gullywash_pro',
    'cp_sunshine',
    'koth_product_final',
    'koth_pro_rc1',
    'cp_prolands_rc2',
    'random_map',
    'cp_process_event',
    'cp_processed_b2',
    'cp_badlands',
    'koth_badlands'
  ] }

  before do
    allow(MapUpload).to receive(:available_maps).and_return(available_maps)
  end

  describe '#search' do
    it 'returns exact matches first' do
      service = described_class.new('cp_process_f12')
      results = service.search
      expect(results.first).to eq('cp_process_f12')
    end

    it 'returns league maps higher in ranking for partial matches' do
      allow(LeagueMaps).to receive(:all_league_maps).and_return([ 'cp_process_f12', 'cp_process_f11', 'cp_process_final', 'koth_product_final' ])
      service = described_class.new('process')
      results = service.search
      expect(results.first).to eq('cp_process_f12')
      expect(results[1..3]).to include('cp_process_f11', 'cp_process_final')
    end

    it 'returns fuzzy matches for non-exact queries' do
      service = described_class.new('gullywsh')  # Misspelled gullywash, dist 2
      results = service.search
      expect(results).to include('cp_gullywash_f9', 'cp_gullywash_pro')
    end

    it 'returns empty array for no matches' do
      service = described_class.new('nonexistentmap')
      expect(service.search).to be_empty
    end

    it 'handles empty search string' do
      service = described_class.new('')
      expect(service.search).to eq([])
    end

    it 'ranks league maps higher than non-league maps' do
      allow(LeagueMaps).to receive(:all_league_maps).and_return([ 'koth_product_final', 'cp_process_f12' ])
      service = described_class.new('pro')
      results = service.search
      league_maps = [ 'koth_product_final', 'cp_process_f12' ]
      non_league_maps = [ 'koth_pro_rc1', 'cp_prolands_rc2' ]

      league_maps.each do |map|
        expect(results.index(map)).to be < results.index(non_league_maps.first) if results.include?(non_league_maps.first)
      end
    end

    it 'ranks prefix matches higher than substring matches' do
      allow(LeagueMaps).to receive(:all_league_maps).and_return([ 'cp_process_f12' ])
      service = described_class.new('process')
      results = service.search
      expect(results.index('cp_process_f12')).to be < results.index('cp_processed_b2')
    end

    it 'prioritizes cp_badlands when searching for "cp badlands"' do
      service = described_class.new('cp badlands')
      results = service.search
      expect(results.first).to eq('cp_badlands')
      expect(results).to include('koth_badlands')
    end

    it 'prioritizes koth_badlands when searching for "koth badlands"' do
      service = described_class.new('koth badlands')
      results = service.search
      expect(results.first).to eq('koth_badlands')
      expect(results).to include('cp_badlands')
    end

    # Helper method to stub map creation easily
    define_method(:create_maps) do |*maps|
      allow(MapUpload).to receive(:available_maps).and_return(maps)
    end

    it 'prioritizes higher f-versions' do
      create_maps('cp_process_f1', 'cp_process_f2', 'cp_process_f3')
      results = described_class.new('process').search
      expect(results).to eq([ 'cp_process_f3', 'cp_process_f2', 'cp_process_f1' ])
    end

    it 'gives bonus to final and pro versions' do
      create_maps('cp_map_final', 'cp_map_pro', 'cp_map_rc1', 'cp_map')
      results = described_class.new('map').search
      # Expect final and pro to be the first two, order might vary based on other scores
      expect(results[0..1]).to contain_exactly('cp_map_final', 'cp_map_pro')
    end

    it 'handles fuzzy matching based on term length' do
      create_maps('cp_granary', 'cp_gravelpit')
      expect(described_class.new('granry').search).to include('cp_granary') # 1 distance, short word
      expect(described_class.new('gravelpitt').search).to include('cp_gravelpit') # 1 distance, long word
      expect(described_class.new('grary').search).not_to include('cp_granary') # 2 distance, too much for short word
    end

    it 'matches partial terms' do
      create_maps('cp_badlands', 'cp_granlands')
      results = described_class.new('lands').search
      expect(results).to contain_exactly('cp_badlands', 'cp_granlands')
    end

    context 'with bonus interactions' do
      let(:league_maps) { [ 'koth_product_rc8' ] } # Assume product rc8 is league
      before { allow(LeagueMaps).to receive(:all_league_maps).and_return(league_maps) }

      it 'ranks league bonus appropriately against version bonus' do
        create_maps('koth_product_rc8', 'koth_product_f12') # League vs High F-ver
        results = described_class.new('product').search
        # Expect league map slightly higher due to bonus (70) vs f-ver bonus (30+12=42)
        expect(results).to eq([ 'koth_product_rc8', 'koth_product_f12' ])
      end

      it 'ranks fuzzy match vs partial match' do
        create_maps('cp_process_b5', 'cp_prolands_rc1') # prolands matches 'pro' partially, process matches fuzzily
        results = described_class.new('proces').search # Fuzzy query for process
        # Expect fuzzy match (process) higher than partial match (prolands)
        # Fuzzy score is higher than partial bonus
        expect(results.first).to eq('cp_process_b5')
      end
    end

    context 'with gatekeeping logic' do
      it 'returns map if only fuzzy match distance is 2' do
        create_maps('cp_process_f1')
        results = described_class.new('processs').search # dist 2
        expect(results).to include('cp_process_f1')
      end

      it 'returns map if only inclusion match exists' do
        create_maps('koth_highlands')
        results = described_class.new('lands').search
        expect(results).to include('koth_highlands')
      end

      it 'does not return map if fuzzy distance is > 2 and no inclusion' do
        create_maps('cp_granary_pro')
        results = described_class.new('grary').search # dist 2, but fuzzy score threshold is 1 for short words
        expect(results).not_to include('cp_granary_pro')
      end
    end

    context 'with multi-word queries' do
      it 'correctly applies multiple bonuses' do
        create_maps('cp_process_final', 'cp_process_f12', 'koth_process_rc1')
        results = described_class.new('cp process final').search
        # Expect cp_process_final first due to prefix, name, and version bonus
        expect(results.first).to eq('cp_process_final')
      end
    end
  end
end
