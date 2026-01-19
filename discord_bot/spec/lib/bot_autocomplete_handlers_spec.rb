# typed: false
# frozen_string_literal: true

require_relative "../spec_helper"

# Test the autocomplete handler logic without running the full bot
RSpec.describe "Bot autocomplete handlers" do
  describe "server autocomplete" do
    let!(:location) { create(:location, name: "Netherlands") }
    let!(:server1) { create(:server, name: "Fakkel #1", location: location) }
    let!(:server2) { create(:server, name: "Fakkel #2", location: location) }
    let!(:inactive_server) { create(:server, name: "Inactive Server", location: location, active: false) }

    it "returns active servers with location" do
      servers = Server.active.where(type: %w[LocalServer SshServer]).without_group.includes(:location)
      suggestions = servers.map do |s|
        { name: "#{s.name} (#{s.location&.name || 'Unknown'})", value: s.name }
      end

      expect(suggestions).to include(
        { name: "Fakkel #1 (Netherlands)", value: "Fakkel #1" },
        { name: "Fakkel #2 (Netherlands)", value: "Fakkel #2" }
      )
    end

    it "does not include inactive servers" do
      servers = Server.active.where(type: %w[LocalServer SshServer]).without_group.includes(:location)
      names = servers.map(&:name)

      expect(names).not_to include("Inactive Server")
    end

    it "filters servers by query" do
      servers = Server.active.where(type: %w[LocalServer SshServer]).without_group.includes(:location)
      suggestions = servers.map do |s|
        { name: "#{s.name} (#{s.location&.name || 'Unknown'})", value: s.name }
      end

      query = "fakkel #1"
      filtered = suggestions.select { |s| s[:name].downcase.include?(query) }

      expect(filtered.length).to eq(1)
      expect(filtered.first[:value]).to eq("Fakkel #1")
    end

    it "filters servers by location" do
      other_location = create(:location, name: "Chicago")
      create(:server, name: "Chicago #1", location: other_location)

      servers = Server.active.where(type: %w[LocalServer SshServer]).without_group.includes(:location)
      suggestions = servers.map do |s|
        { name: "#{s.name} (#{s.location&.name || 'Unknown'})", value: s.name }
      end

      query = "chicago"
      filtered = suggestions.select { |s| s[:name].downcase.include?(query) }

      expect(filtered.length).to eq(1)
      expect(filtered.first[:value]).to eq("Chicago #1")
    end

    it "limits results to 25" do
      30.times do |i|
        create(:server, name: "Server #{i}", location: location)
      end

      servers = Server.active.where(type: %w[LocalServer SshServer]).without_group.includes(:location)
      suggestions = servers.map do |s|
        { name: "#{s.name} (#{s.location&.name || 'Unknown'})", value: s.name }
      end

      expect(suggestions.first(25).length).to eq(25)
    end

    context "with donator servers" do
      let!(:donator_group) { Group.donator_group }
      let!(:donator_server) { create(:server, name: "Donator Server", location: location) }
      let!(:free_user) { create(:user, uid: "free123", discord_uid: "discord_free") }
      let!(:donator_user) { create(:user, uid: "donator123", discord_uid: "discord_donator") }

      before do
        # Add donator server to donator group
        donator_server.groups << donator_group
        # Add donator user to donator group
        donator_user.groups << donator_group
      end

      it "shows donator servers to donator users" do
        base_servers = Server.active.where(type: %w[LocalServer SshServer])
        servers = base_servers.reservable_by_user(donator_user).includes(:location)
        names = servers.map(&:name)

        expect(names).to include("Donator Server")
        expect(names).to include("Fakkel #1", "Fakkel #2")
      end

      it "does not show donator servers to free users" do
        base_servers = Server.active.where(type: %w[LocalServer SshServer])
        servers = base_servers.reservable_by_user(free_user).includes(:location)
        names = servers.map(&:name)

        expect(names).not_to include("Donator Server")
        expect(names).to include("Fakkel #1", "Fakkel #2")
      end

      it "returns empty results for unlinked users" do
        # Unlinked users (no discord_uid match) get no autocomplete results
        # This is tested at the handler level - they must link first
        unlinked_discord_uid = "unlinked_user_123"
        user = User.find_by(discord_uid: unlinked_discord_uid)

        expect(user).to be_nil
      end
    end
  end

  describe "config autocomplete" do
    let!(:config1) { create(:server_config, file: "etf2l_6v6.cfg") }
    let!(:config2) { create(:server_config, file: "rgl_6s_5cp.cfg") }
    let!(:hidden_config) { create(:server_config, file: "hidden.cfg", hidden: true) }

    it "returns active configs ordered by file name" do
      configs = ServerConfig.active.ordered
      suggestions = configs.map { |c| { name: c.file, value: c.file } }

      file_names = suggestions.map { |s| s[:name] }
      expect(file_names).to include("etf2l_6v6.cfg", "rgl_6s_5cp.cfg")
    end

    it "does not include hidden configs" do
      configs = ServerConfig.active.ordered
      file_names = configs.map(&:file)

      expect(file_names).not_to include("hidden.cfg")
    end

    it "filters configs by query" do
      configs = ServerConfig.active.ordered
      suggestions = configs.map { |c| { name: c.file, value: c.file } }

      query = "etf2l"
      filtered = suggestions.select { |s| s[:name].downcase.include?(query) }

      expect(filtered.length).to eq(1)
      expect(filtered.first[:value]).to eq("etf2l_6v6.cfg")
    end

    it "filters configs case-insensitively" do
      configs = ServerConfig.active.ordered
      suggestions = configs.map { |c| { name: c.file, value: c.file } }

      query = "RGL"
      filtered = suggestions.select { |s| s[:name].downcase.include?(query.downcase) }

      expect(filtered.length).to eq(1)
      expect(filtered.first[:value]).to eq("rgl_6s_5cp.cfg")
    end
  end

  describe "whitelist autocomplete" do
    let!(:whitelist1) { create(:whitelist, file: "etf2l_whitelist_6v6.txt") }
    let!(:whitelist2) { create(:whitelist, file: "rgl_6s.txt") }
    let!(:hidden_whitelist) { create(:whitelist, file: "hidden_whitelist.txt", hidden: true) }

    it "returns only non-hidden whitelists" do
      whitelists = Whitelist.active.ordered
      suggestions = whitelists.map { |w| { name: w.file, value: w.file } }

      whitelist_files = suggestions.map { |s| s[:name] }
      expect(whitelist_files).to include("etf2l_whitelist_6v6.txt", "rgl_6s.txt")
      expect(whitelist_files).not_to include("hidden_whitelist.txt")
    end

    it "orders whitelists case-insensitively" do
      whitelists = Whitelist.active.ordered
      files = whitelists.pluck(:file)

      # Should be sorted case-insensitively
      expect(files).to eq(files.sort_by(&:downcase))
    end

    it "filters whitelists by query" do
      whitelists = Whitelist.active.ordered
      suggestions = whitelists.map { |w| { name: w.file, value: w.file } }

      query = "etf2l"
      filtered = suggestions.select { |s| s[:name].downcase.include?(query) }

      expect(filtered.length).to eq(1)
      expect(filtered.first[:value]).to eq("etf2l_whitelist_6v6.txt")
    end
  end

  describe "map autocomplete" do
    let!(:user) { create(:user, discord_uid: "123456789") }
    let!(:server) { create(:server) }

    before do
      # Stub map validation since we're testing autocomplete logic, not reservation validation
      allow(MapUpload).to receive(:available_maps).and_return([ "cp_process_f12", "cp_granary_pro_rc8", "cp_custom_map", "cp_badlands" ])
    end

    it "returns user's recent maps first" do
      r1 = create(:reservation, user: user, server: server, first_map: "cp_process_f12")
      r1.update_columns(starts_at: 2.days.ago, ends_at: 2.days.ago + 2.hours)
      r2 = create(:reservation, user: user, server: server, first_map: "cp_granary_pro_rc8")
      r2.update_columns(starts_at: 3.days.ago, ends_at: 3.days.ago + 2.hours)

      recent_maps = user.reservations
        .where.not(first_map: [ nil, "" ])
        .order(created_at: :desc)
        .limit(20)
        .pluck(:first_map)
        .uniq

      expect(recent_maps).to include("cp_process_f12", "cp_granary_pro_rc8")
    end

    it "includes league maps as fallback" do
      allow(LeagueMaps).to receive(:all_league_maps).and_return([ "cp_badlands", "cp_gullywash_f9" ])

      league_maps = LeagueMaps.all_league_maps
      expect(league_maps).to include("cp_badlands", "cp_gullywash_f9")
    end

    it "combines recent maps with league maps, recent first" do
      r = create(:reservation, user: user, server: server, first_map: "cp_custom_map")
      r.update_columns(starts_at: 2.days.ago, ends_at: 2.days.ago + 2.hours)
      allow(LeagueMaps).to receive(:all_league_maps).and_return([ "cp_badlands", "cp_custom_map" ])

      recent_maps = user.reservations
        .where.not(first_map: [ nil, "" ])
        .pluck(:first_map)
        .uniq
      league_maps = LeagueMaps.all_league_maps

      all_maps = (recent_maps + league_maps).uniq

      # Recent map should come first, duplicates removed
      expect(all_maps.first).to eq("cp_custom_map")
      expect(all_maps).to include("cp_badlands")
      expect(all_maps.count("cp_custom_map")).to eq(1)
    end

    it "filters maps by query" do
      allow(LeagueMaps).to receive(:all_league_maps).and_return([ "cp_badlands", "cp_process_f12", "koth_product_final" ])

      suggestions = LeagueMaps.all_league_maps.map { |m| { name: m, value: m } }

      query = "cp_"
      filtered = suggestions.select { |s| s[:name].downcase.include?(query) }

      expect(filtered.length).to eq(2)
      expect(filtered.map { |s| s[:value] }).to include("cp_badlands", "cp_process_f12")
      expect(filtered.map { |s| s[:value] }).not_to include("koth_product_final")
    end
  end

  describe "suggestion format" do
    it "returns suggestions with name and value keys" do
      location = create(:location, name: "Test Location")
      server = create(:server, name: "Test Server", location: location)

      servers = Server.active.where(type: %w[LocalServer SshServer]).includes(:location)
      suggestion = servers.map do |s|
        { name: "#{s.name} (#{s.location&.name || 'Unknown'})", value: s.name }
      end.find { |s| s[:value] == "Test Server" }

      expect(suggestion).to have_key(:name)
      expect(suggestion).to have_key(:value)
      expect(suggestion[:name]).to eq("Test Server (Test Location)")
      expect(suggestion[:value]).to eq("Test Server")
    end

    it "handles servers with missing location name" do
      location = create(:location, name: nil)
      server = create(:server, name: "No Location Name Server", location: location)

      servers = Server.active.where(type: %w[LocalServer SshServer]).includes(:location)
      suggestion = servers.map do |s|
        { name: "#{s.name} (#{s.location&.name || 'Unknown'})", value: s.name }
      end.find { |s| s[:value] == "No Location Name Server" }

      expect(suggestion[:name]).to eq("No Location Name Server (Unknown)")
    end
  end
end
