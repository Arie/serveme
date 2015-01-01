class PaypalOrder < ActiveRecord::Base
  include PaypalPayment

  belongs_to :product
  belongs_to :user

  attr_accessible :product, :product_id, :payment_id, :payer_id, :status
  delegate :name, :to => :product, :allow_nil => true, :prefix => true

  validates_presence_of :user_id, :product_id

  def complete_payment!
    update_attributes(:status => "Completed")
    AddGroupMembership.new(product.days, user).perform
    if product.grants_private_server?
      AddGroupMembership.new(product.days, user, Group.private_user(user)).perform
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

  def self.monthly_goal(site_host = SITE_HOST)
    if site_host == "serveme.tf"
      250.0
    elsif site_host == "na.serveme.tf"
      100.0
    else
      50.0
    end
  end

end
