# frozen_string_literal: true
class PaypalOrder < ActiveRecord::Base
  include PaypalPayment

  belongs_to :product
  belongs_to :user

  attr_accessible :product, :product_id, :payment_id, :payer_id, :status, :gift
  delegate :name, :to => :product, :allow_nil => true, :prefix => true

  validates_presence_of :user_id, :product_id

  def complete_payment!
    update_attributes(:status => "Completed")
    if gift?
      GeneratePaypalVoucher.new(self).perform
    else
      GrantPerks.new(product, user).perform
    end
    announce_donator
  end

  def announce_donator
    AnnounceDonatorWorker.perform_async(self.id)
  end

  def self.monthly_total(now = Time.current)
    completed.monthly(now).joins(:product).sum('products.price')
  end

  def self.completed
    where(:status => "Completed")
  end

  def self.monthly_goal_percentage(now = Time.current)
    (monthly_total(now) / monthly_goal) * 100.0
  end

  def self.monthly(now = Time.current)
    beginning_of_month = now.beginning_of_month
    end_of_month = now.end_of_month
    where('paypal_orders.created_at > ? AND paypal_orders.created_at < ?', beginning_of_month, end_of_month)
  end

  def self.leaderboard
    completed.group(:user).joins(:user).joins(:product).sum('products.price').sort_by do |user, amount|
      amount
    end.reverse
  end

  def self.monthly_goal(site_host = SITE_HOST)
    if site_host == "serveme.tf"
      300.0
    elsif site_host == "na.serveme.tf"
      175.0
    elsif site_host == "au.serveme.tf"
      75.0
    else
      50.0
    end
  end

end
