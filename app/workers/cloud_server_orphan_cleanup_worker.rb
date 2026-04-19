# typed: true
# frozen_string_literal: true

class CloudServerOrphanCleanupWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: "default"

  MIN_AGE = 10.minutes
  VM_PROVIDERS = %w[vultr hetzner].freeze

  def perform
    region_prefix = "#{region_label}-"

    VM_PROVIDERS.each do |provider_name|
      provider = CloudProvider.for(provider_name)
      cleanup_provider(provider, provider_name, region_prefix)
    rescue => e
      Rails.logger.error "CloudServerOrphanCleanupWorker: Error checking #{provider_name}: #{e.message}"
    end
  end

  private

  def cleanup_provider(provider, provider_name, region_prefix)
    all_vms = provider.list_servers
    our_vms = all_vms.select { |vm| vm[:label].to_s.start_with?(region_prefix) }
    return if our_vms.empty?

    active_provider_ids = CloudServer
      .where(cloud_provider: provider_name)
      .where.not(cloud_status: "destroyed")
      .where.not(cloud_provider_id: nil)
      .pluck(:cloud_provider_id)
      .to_set

    our_vms.each do |vm|
      next if active_provider_ids.include?(vm[:provider_id])
      next if vm[:created_at] && vm[:created_at] > MIN_AGE.ago

      Rails.logger.warn "CloudServerOrphanCleanupWorker: Destroying orphan #{provider_name} VM #{vm[:provider_id]} (label: #{vm[:label]})"
      provider.destroy_server(vm[:provider_id])
    end
  end

  def region_label
    region = SITE_HOST == "serveme.tf" ? "eu" : SITE_HOST.split(".").first
    "serveme-#{region}"
  end
end
