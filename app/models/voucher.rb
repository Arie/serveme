class Voucher < ActiveRecord::Base

  belongs_to :product
  belongs_to :user, :foreign_key => :claimed_by
  attr_accessible :code, :product

  def self.generate!(product)
    voucher = create!(product: product, code: generate_code)
    Base32::Crockford.hypenate(voucher.code).upcase
  end

  def self.generate_code
    encode(SecureRandom.hex(8).to_i(16))
  end

  def self.encode(code)
    Base32::Crockford.encode(code).upcase
  end

  def self.unclaimed
    where(claimed_at: nil)
  end

  def self.find_by_code(code)
    begin
      code = encode(Base32::Crockford.decode(code, :integer))
      where(code: code).first
    rescue
      nil
    end
  end

  def claim!(user)
    with_lock do
      reload
      raise AlreadyClaimed if claimed?
      self[:claimed_by] = user.id
      self[:claimed_at] = Time.current
      GrantPerks.new(product, user).perform
      save!
    end
  end

  def claimed?
    claimed_at?
  end

  AlreadyClaimed = Class.new(RuntimeError)

end
