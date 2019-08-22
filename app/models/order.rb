# frozen_string_literal: true
class Order < ActiveRecord::Base
  self.table_name = :paypal_orders
  belongs_to :product
  belongs_to :user
  has_one :voucher

  attr_accessor :source_type
  delegate :name, to: :product, allow_nil: true, prefix: true

  validates_presence_of :user_id, :product_id

  def handle_successful_payment!
    update(status: 'Completed')
    if gift?
      GenerateOrderVoucher.new(self).perform
    else
      GrantPerks.new(product, user).perform
    end
    announce_donator
  end

  def announce_donator
    AnnounceDonatorWorker.perform_async(user.nickname, product_name)
  end

  def self.monthly_total(now = Time.current)
    completed.monthly(now).joins(:product).sum('products.price')
  end

  def self.completed
    where(status: 'Completed')
  end

  def self.monthly_goal_percentage(now = Time.current)
    (monthly_total(now) / monthly_goal) * 100.0
  end

  def self.monthly(now = Time.current)
    beginning_of_month = now.beginning_of_month
    end_of_month = now.end_of_month
    where(arel_table[:created_at].gt(beginning_of_month)).
      where(arel_table[:created_at].lt(end_of_month))
  end

  def self.leaderboard
    completed.group(:user).joins(:user).joins(:product).sum('products.price').sort_by do |_user, amount|
      amount
    end.reverse
  end

  def self.monthly_goal(site_host = SITE_HOST)
    if site_host == 'serveme.tf'
      250.0
    elsif site_host == 'na.serveme.tf'
      175.0
    elsif site_host == 'sea.serveme.tf'
      60.0
    else
      50.0
    end
  end
end
