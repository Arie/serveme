# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe GrantPerks do
  let(:user) { create(:user, uid: '76561197960497430') }

  define_method(:donator_membership) do
    user.group_users.find_by(group_id: Group.donator_group)
  end

  define_method(:private_membership) do
    private_group = Group.where(name: user.uid).first
    return nil unless private_group

    user.group_users.find_by(group_id: private_group)
  end

  describe '#perform with a plain donator product' do
    let(:product) { create(:product, days: 30, grants_private_server: false) }

    it 'grants donator group membership expiring in product.days days' do
      freeze_time do
        expect {
          described_class.new(product, user).perform
        }.to change { donator_membership }.from(nil)

        expect(donator_membership.expires_at).to be_within(1.second).of(30.days.from_now)
      end
    end

    it 'does not create or grant a private user group' do
      expect {
        described_class.new(product, user).perform
      }.not_to change { Group.where(name: user.uid).count }

      expect(private_membership).to be_nil
    end

    it 'extends an existing (still active) donator membership by product.days' do
      freeze_time do
        original_expiry = 10.days.from_now
        create(:group_user, user: user, group: Group.donator_group, expires_at: original_expiry)

        described_class.new(product, user).perform

        expect(donator_membership.expires_at).to be_within(1.second).of(original_expiry + 30.days)
      end
    end

    it 'resets a former (expired) donator membership to product.days from now' do
      freeze_time do
        create(:group_user, user: user, group: Group.donator_group, expires_at: 5.days.ago)

        described_class.new(product, user).perform

        expect(donator_membership.reload.expires_at).to be_within(1.second).of(30.days.from_now)
      end
    end
  end

  describe '#perform with a private-server product' do
    let(:product) { create(:product, days: 90, grants_private_server: true) }

    it 'grants donator group membership' do
      described_class.new(product, user).perform

      expect(donator_membership).to be_present
    end

    it "creates the user's private group and grants membership expiring in product.days" do
      freeze_time do
        expect {
          described_class.new(product, user).perform
        }.to change { Group.where(name: user.uid).count }.from(0).to(1)

        expect(private_membership).to be_present
        expect(private_membership.expires_at).to be_within(1.second).of(90.days.from_now)
      end
    end

    it 'extends both donator and private memberships when re-purchased while active' do
      freeze_time do
        described_class.new(product, user).perform
        first_donator_expiry = donator_membership.expires_at
        first_private_expiry = private_membership.expires_at

        described_class.new(product, user).perform

        expect(donator_membership.reload.expires_at).to be_within(1.second).of(first_donator_expiry + 90.days)
        expect(private_membership.reload.expires_at).to be_within(1.second).of(first_private_expiry + 90.days)
      end
    end
  end
end
