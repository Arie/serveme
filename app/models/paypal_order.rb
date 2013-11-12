class PaypalOrder < ActiveRecord::Base
  include PaypalPayment

  belongs_to :product
  belongs_to :user

  attr_accessible :product_id, :payment_id, :payer_id, :status

  validates_presence_of :user_id, :product_id

  def complete_payment!
    update_attributes(:status => "Completed")
    update_donator_status
  end

  def update_donator_status
    donator_status.expires_at = new_expiration_time
    donator_status.save
  end

  def new_expiration_time
    days_to_add = product.days
    if first_time_donator? || former_donator?
      days_to_add.days.from_now
    else
      donator_status.expires_at + days_to_add.days
    end
  end

  def donator_status
    @donator_status ||= user.group_users.where(:group_id => Group.donator_group).first_or_initialize
  end

  def first_time_donator?
    donator_status.new_record?
  end

  def former_donator?
    donator_status.expires_at < Time.current
  end

  def self.monthly_total(now = Time.current)
    where(:status => "Completed").monthly(now).joins(:product).sum('products.price')
  end

  def self.monthly_goal_percentage(now = Time.current)
    (monthly_total(now) / monthly_goal) * 100.0
  end

  def self.monthly(now = Time.current)
    beginning_of_month = now.beginning_of_month
    end_of_month = now.end_of_month
    where('paypal_orders.created_at > ? AND paypal_orders.created_at < ?', beginning_of_month, end_of_month)
  end

  def self.monthly_goal
    100.0
  end

end
