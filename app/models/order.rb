# typed: true
# frozen_string_literal: true

class Order < ActiveRecord::Base
  extend T::Sig

  self.table_name = :paypal_orders
  belongs_to :product
  belongs_to :user
  has_one :voucher

  attr_accessor :source_type

  delegate :name, to: :product, allow_nil: true, prefix: true

  validates_presence_of :user_id, :product_id

  sig { returns(T.nilable(String)) }
  def handle_successful_payment!
    update(status: 'Completed')
    if gift?
      GenerateOrderVoucher.new(self).perform
    else
      GrantPerks.new(product, user).perform
    end
    announce_donator
  end

  sig { returns(T.nilable(String)) }
  def announce_donator
    AnnounceDonatorWorker.perform_async(user&.nickname, product_name)
  end

  sig { params(now: ActiveSupport::TimeWithZone).returns(T.any(Integer, Float, BigDecimal)) }
  def self.monthly_total(now = Time.current)
    completed.monthly(now).joins(:product).sum('products.price')
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy, T.untyped)) }
  def self.completed
    where(status: 'Completed')
  end

  sig { params(now: ActiveSupport::TimeWithZone).returns(T.any(Float, BigDecimal)) }
  def self.monthly_goal_percentage(now = Time.current)
    (monthly_total(now) / monthly_goal) * 100.0
  end

  sig { params(now: ActiveSupport::TimeWithZone).returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.monthly(now = Time.current)
    beginning_of_month = now.beginning_of_month
    end_of_month = now.end_of_month
    where(arel_table[:created_at].gt(beginning_of_month))
      .where(arel_table[:created_at].lt(end_of_month))
  end

  sig { params(site_host: String).returns(Float) }
  def self.monthly_goal(site_host = SITE_HOST)
    case site_host
    when 'serveme.tf'
      340.0
    when 'na.serveme.tf'
      350.0
    when 'sea.serveme.tf'
      60.0
    else
      50.0
    end
  end

  sig { returns(T::Array[T::Array[T.any(Integer, User)]]) }
  def self.leaderboard_by_time
    completed.group(:user).joins(:user).joins(:product).sum('products.days').sort_by do |_user, time|
      time
    end.reverse
  end
end
